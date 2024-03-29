#!/usr/bin/python3

import logging
import json
from os import getenv
from sys import exit
import time
import boto3
from botocore.client import Config
from azure.storage.blob import (
    BlobServiceClient,
    BlobClient,
    ContainerClient,
    __version__,
)
import os
import sys
import pymysql


def GetenvOrFail(var, redact_log=False):
    val = getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        exit(1)
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val


def connect_memsql():
    return pymysql.connect(
        host=GetenvOrFail("MEMSQL_HOSTNAME"),
        user=getenv("MEMSQL_USERNAME", "root"),
        password=GetenvOrFail("MEMSQL_PASSWORD", True),
    )


class BackupInfo:
    def __init__(self, path, is_incremental):
        self.path = path
        self.is_incremental = is_incremental


def GenerateInitBackupPath(backup_bucket, backup_prefix):
    timestamp = time.strftime("%Y-%m-%d-%H-%M", time.gmtime())
    return "{}/{}/{}".format(backup_bucket, backup_prefix, timestamp)


# Endpoint variable is only used in dev/testing, used by minio/azurite
# In this case we append 'http' (and ensure there are no duplication of the prefix)
def checkBackupEndpoint(cspType, endpoint):
    if cspType == "S3":
        endpoint = endpoint.replace("http://", "")
        endpoint = "http://" + endpoint
    return endpoint


def FullPathForBackup(
    cursor, db, is_incremental, full_backup_only, backup_bucket, backup_prefix, csp_type
):
    if full_backup_only:
        backup_location = GenerateInitBackupPath(backup_bucket, backup_prefix)
        return BackupInfo(backup_location, False)

    query_options = {}
    query_options["db"] = db
    query_options["bucket"] = backup_bucket
    query_options["path_prefix"] = backup_prefix
    query_options["csp_type"] = csp_type

    # When it is a incremental backup job but there is no existing init backup or there is no init backup
    # job in progress, the incremental backup job will try to do a init backup.

    # If this is an incremental backup job, but there is a init backup for the same db that is in progress,
    # skip this job.
    # If this is an a init backup job, but there is a init backup in progress (could be a incremental
    # backup job doing a init backup), skip this init backup job.
    query_template = (
        "SELECT "
        "command , state, info "
        "FROM information_schema.processlist "
        "WHERE command = 'Query' AND "
        "info LIKE 'BACKUP DATABASE {db} "
        "WITH INIT to {csp_type} \"{bucket}/{path_prefix}/_%'"
    )
    expanded_query = query_template.format(**query_options)
    logging.info(expanded_query)
    cursor.execute(expanded_query)
    rows = cursor.fetchall()
    if rows:
        logging.info(
            "INIT backup in progress for DB {} at {}/{}_..., skipping this {} backup".format(
                db,
                query_options["bucket"],
                query_options["path_prefix"],
                "incremental" if is_incremental else "init",
            )
        )
        return BackupInfo("", is_incremental)

    if not is_incremental:
        backup_location = GenerateInitBackupPath(backup_bucket, backup_prefix)
        return BackupInfo(backup_location, False)

    # there is no init backup in progress, check to see if there are existing init backups.
    query_template = (
        "SELECT "
        "backup_id, incr_backup_id, backup_path, status "
        "FROM information_schema.mv_backup_history "
        "WHERE "
        "database_name = '{db}' AND "
        "incr_backup_id IS NOT NULL AND "
        "status = 'Success' AND "
        "backup_path LIKE '{bucket}/{path_prefix}/_%' "
        "ORDER BY backup_id DESC, incr_backup_id DESC "
        "LIMIT 1"
    )

    expanded_query = query_template.format(**query_options)
    logging.info(expanded_query)
    cursor.execute(expanded_query)
    rows = cursor.fetchall()

    if rows:
        # do an incremental backup based on the latest init backup
        backup_path = rows[0]["backup_path"] if type(rows[0]) is dict else rows[0][2]
        return BackupInfo(backup_path[0 : backup_path.rindex("/")], True)
    else:
        logging.info(
            "There is no INIT backups for DB {} at {}/{}_..., doing INIT backup instead".format(
                db, query_options["bucket"], query_options["path_prefix"]
            )
        )
        backup_location = GenerateInitBackupPath(backup_bucket, backup_prefix)
        return BackupInfo(backup_location, False)


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)-15s: %(levelname)-8s: %(message)s"
    )
    logging.info("Running backup job")

    # Get the storage provider type from the environment
    csp_type = getenv("CSP_TYPE")
    # Backwards compatibility: In old versions of helios, this env var does not exist as all backups were sent to S3 buckets
    # So by default we attempt to backup to S3 bucket and assume S3 creds were passed
    if csp_type is None:
        csp_type = "S3"

    # Get the BACKUP CONFIG paramaters from the environment
    backup_config = {}
    backup_endpoint = getenv("MEMSQL_BACKUP_ENDPOINT")

    if backup_endpoint is not None:
        backup_endpoint = checkBackupEndpoint(csp_type, backup_endpoint)

    logging.info("backup_endpoint:", backup_endpoint)

    backup_region = getenv("MEMSQL_BACKUP_REGION")
    if backup_region is not None:
        backup_config["region"] = backup_region

    compatibility_mode = getenv("COMPATIBILITY_MODE")
    if compatibility_mode is not None:
        # we only accept "true" or "false" as the env value for compatibility mode
        if compatibility_mode == "true":
            backup_config["compatibility_mode"] = True
        elif compatibility_mode == "false":
            backup_config["compatibility_mode"] = False
        else:
            logging.error(
                "Invalid Environment Variable Found {}".format(compatibility_mode)
            )
            exit(1)

    # Get the credentials from the environment
    # Populate backup_creds (credentials_json) key names according to the CloudServiceProvider
    backup_creds = {}

    if csp_type == "S3":
        # Backwards compatibility: old versions pass in AWS_ACCESS_KEY and AWS_SECRET_ACCESS_KEY
        if "AWS_ACCESS_KEY" in os.environ:
            backup_creds["aws_access_key_id"] = GetenvOrFail("AWS_ACCESS_KEY")
            backup_creds["aws_secret_access_key"] = GetenvOrFail(
                "AWS_SECRET_ACCESS_KEY", True
            )
        else:
            backup_creds["aws_access_key_id"] = GetenvOrFail("CSP_ACCESS_KEY")
            backup_creds["aws_secret_access_key"] = GetenvOrFail("CSP_SECRET_KEY", True)
        if backup_endpoint is not None:
            backup_config["endpoint_url"] = backup_endpoint

    elif csp_type == "GCS":
        backup_creds["access_id"] = GetenvOrFail("CSP_ACCESS_KEY")
        backup_creds["secret_key"] = GetenvOrFail("CSP_SECRET_KEY", True)

    elif csp_type == "AZURE":
        backup_creds["account_name"] = GetenvOrFail("CSP_ACCESS_KEY")
        backup_creds["account_key"] = GetenvOrFail("CSP_SECRET_KEY", True)

        # For azurite only
        if backup_endpoint is not None and backup_endpoint.startswith("http://"):
            backup_config["blob_endpoint"] = backup_endpoint
    else:
        logging.error(
            "Invalid Environment Variable Found (csp_type): {}".format(csp_type)
        )
        exit(1)

    is_incremental = GetenvOrFail("MEMSQL_BACKUP_INCREMENTAL") == "true"
    full_backup_only_env = getenv("MEMSQL_FULL_BACKUP_ONLY")
    full_backup_only = (
        full_backup_only_env and full_backup_only_env == "true" and not is_incremental
    )

    # Get the database connection information from the environment
    memsql_hostname = GetenvOrFail("MEMSQL_HOSTNAME")

    memsql_user = getenv("MEMSQL_USERNAME", "root")
    logging.info('Using username "{}"'.format(memsql_user))

    memsql_password = GetenvOrFail("MEMSQL_PASSWORD", True)

    backup_bucket = GetenvOrFail("MEMSQL_BACKUP_BUCKET")
    backup_prefix = GetenvOrFail("MEMSQL_BACKUP_NAME")
    backup_jobID = getenv("MEMSQL_BACKUP_JOBID")
    is_manual_backup = False
    if backup_jobID is not None:
        metadataFile = "metadata.json"
        is_manual_backup = True

    logging.info("Connecting to target cluster")

    # Connect to the target cluster
    db = connect_memsql()

    logging.info("Connected to target cluster, retrieving database list")

    # Get the list of databases
    c = db.cursor()
    selectDatabases = (
        "SELECT DATABASE_NAME FROM INFORMATION_SCHEMA.DISTRIBUTED_DATABASES"
    )
    c.execute(selectDatabases)
    dbs = list(map(lambda x: x[0], c.fetchall()))

    logging.info("Found {} databases".format(len(dbs)))

    # Run the backups
    query_template = "BACKUP DATABASE `{db}` WITH {mode} TO {csp_type} \"{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"
    if full_backup_only:
        query_template = "BACKUP DATABASE `{db}` TO {csp_type} \"{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"

    query_options = {}
    query_options["csp_type"] = csp_type
    query_options["config"] = json.dumps(backup_config)
    for db in dbs:
        backup_info = FullPathForBackup(
            c,
            db,
            is_incremental,
            full_backup_only,
            backup_bucket,
            backup_prefix,
            csp_type,
        )
        # overwriting the backup path here because backup_jobID is defined which means we are doing a manual backup
        if is_manual_backup:
            backup_info.path = "{}/{}/{}".format(
                backup_bucket, backup_prefix, backup_jobID
            )
        if backup_info.path:
            query_options["db"] = db
            if not full_backup_only:
                query_options["mode"] = (
                    "DIFFERENTIAL" if backup_info.is_incremental else "INIT"
                )
            query_options["path"] = backup_info.path
            logging.info(
                query_template.format(credentials="<redacted>", **query_options)
            )
            c.execute(
                query_template.format(
                    credentials=json.dumps(backup_creds), **query_options
                )
            )
            c.fetchall()
            if full_backup_only:
                logging.info(
                    "Finished full backup of database `{}` at {}".format(
                        db, backup_info.path
                    )
                )
            else:
                logging.info(
                    "Finished {} backup of database `{}` at {}".format(
                        query_options["mode"], db, backup_info.path
                    )
                )

    if is_manual_backup:
        # Generate additional metadata file for use in restoring backups
        with open(metadataFile, "w+") as f:
            json.dump(dbs, f)

        if csp_type == "S3" or csp_type == "GCS":
            s3 = boto3.resource(
                "s3",
                endpoint_url=backup_endpoint,
                aws_access_key_id=backup_creds["aws_access_key_id"],
                aws_secret_access_key=backup_creds["aws_secret_access_key"],
                config=Config(signature_version="s3v4"),
                region_name=backup_region,
            )

            s3.Bucket(backup_bucket).upload_file(
                metadataFile, backup_prefix + "/" + backup_jobID + "/" + metadataFile
            )

        if csp_type == "AZURE":
            blob_service_client = BlobServiceClient(
                account_url=backup_endpoint,
                credential=backup_creds,
                api_version="2019-12-12",
            )
            # Connect to the container
            blob_client = blob_service_client.get_blob_client(
                container=backup_bucket,
                blob=metadataFile,
            )
            with open(metadataFile, "rb") as data:
                blob_client.upload_blob(data, overwrite=True)

            logging.info(
                "Wrote 'metadata.json with dbList: {} to bucket {} with prefix {}".format(
                    json.dumps(dbs), backup_bucket, backup_prefix
                )
            )

    logging.info("Done")


if __name__ == "__main__":
    main()
