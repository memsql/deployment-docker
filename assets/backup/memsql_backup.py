#!/usr/bin/python2.7

import logging
import json
from os import getenv
from sys import exit
import time

import MySQLdb


def GetenvOrFail(var, redact_log=False):
    val = getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        exit(1)
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val

class BackupInfo:
    def __init__(self, path, is_incremental):
        self.path = path
        self.is_incremental = is_incremental

def GenerateInitBackupPath(backup_bucket, backup_prefix):
    timestamp = time.strftime("%Y-%m-%d-%H-%M", time.gmtime())
    return "{}/{}_{}".format(backup_bucket, backup_prefix, timestamp)

def FullPathForBackup(cursor, db, is_incremental, full_backup_only, backup_bucket, backup_prefix):
    if full_backup_only:
        backup_location = GenerateInitBackupPath(backup_bucket, backup_prefix)
        return BackupInfo(backup_location, False)

    query_options = {}
    query_options["db"] = db
    query_options["bucket"] = backup_bucket
    query_options["path_prefix"] = backup_prefix

    # When it is a incremental backup job but there is no existing init backup or there is no init backup
    # job in progress, the incremental backup job will try to do a init backup.

    # If this is an incremental backup job, but there is a init backup for the same db that is in progress,
    # skip this job.
    # If this is an a init backup job, but there is a init backup in progress (could be a incremental 
    # backup job doing a init backup), skip this init backup job.
    query_template=(
        "SELECT "
        "command , state, info "
        "FROM information_schema.processlist "
        "WHERE command = 'Query' AND "
        "info LIKE 'BACKUP DATABASE {db} "
        "WITH INIT to S3 \"{bucket}/{path_prefix}\_%'")
    expanded_query = query_template.format(**query_options)
    logging.info(expanded_query)
    cursor.execute(expanded_query)
    rows = cursor.fetchall()
    if rows:
        logging.info("INIT backup in progress for DB {} at {}/{}_..., skipping this {} backup"
                .format(db, query_options["bucket"], query_options["path_prefix"],
                    "incremental" if is_incremental else "init"))
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
        "backup_path LIKE '{bucket}/{path_prefix}\_%' "
        "ORDER BY backup_id DESC, incr_backup_id DESC "
        "LIMIT 1")

    expanded_query = query_template.format(**query_options)
    logging.info(expanded_query)
    cursor.execute(expanded_query)
    rows = cursor.fetchall()

    if rows:
        # do an incremental backup based on the latest init backup
        backup_path = rows[0]['backup_path'] if type(rows[0]) is dict else rows[0][2]
        return BackupInfo(backup_path[0:backup_path.rindex("/")], True)
    else:
        logging.info("There is no INIT backups for DB {} at {}/{}_..., doing INIT backup instead"
                .format(db, query_options["bucket"], query_options["path_prefix"]))
        backup_location = GenerateInitBackupPath(backup_bucket, backup_prefix)
        return BackupInfo(backup_location, False)


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)-15s: %(levelname)-8s: %(message)s")

    # Get the AWS credentials from the environment
    backup_creds = {}
    backup_creds["aws_access_key_id"] = GetenvOrFail("AWS_ACCESS_KEY")
    backup_creds["aws_secret_access_key"] = GetenvOrFail("AWS_SECRET_ACCESS_KEY", True)
    is_incremental = GetenvOrFail("MEMSQL_BACKUP_INCREMENTAL") == "true"
    full_backup_only_env = getenv("MEMSQL_FULL_BACKUP_ONLY")
    full_backup_only = full_backup_only_env and full_backup_only_env == "true" and not is_incremental

    # Get the BACKUP CONFIG paramaters from the environment
    backup_config = {}

    backup_endpoint = getenv("MEMSQL_BACKUP_ENDPOINT")
    if backup_endpoint is not None:
        backup_config["endpoint_url"] = backup_endpoint

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
            logging.error("Invalid Environment Variable Found {}".format(compatibility_mode))
            exit(1)

    # Get the database connection information from the environment
    memsql_hostname = GetenvOrFail("MEMSQL_HOSTNAME")

    memsql_user = getenv("MEMSQL_USERNAME", "root")
    logging.info("Using username \"{}\"".format(memsql_user))

    memsql_password = GetenvOrFail("MEMSQL_PASSWORD", True)

    backup_bucket = GetenvOrFail("MEMSQL_BACKUP_BUCKET")
    backup_prefix = GetenvOrFail("MEMSQL_BACKUP_NAME")

    logging.info("Connecting to target cluster")


    # Connect to the target cluster
    db = MySQLdb.connect(host=memsql_hostname, user=memsql_user, passwd=memsql_password)

    logging.info("Connected to target cluster, retrieving database list")

    # Get the list of databases
    c = db.cursor()
    c.execute("SELECT DATABASE_NAME FROM INFORMATION_SCHEMA.DISTRIBUTED_DATABASES")
    dbs = map(lambda x: x[0], c.fetchall())

    logging.info("Found {} databases".format(len(dbs)))

    # Run the backups
    query_template = "BACKUP DATABASE `{db}` WITH {mode} TO S3 \"{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"
    if full_backup_only:
        query_template = "BACKUP DATABASE `{db}` TO S3 \"{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"

    query_options = {}
    query_options["config"] = json.dumps(backup_config)
    for db in dbs:
        backup_info = FullPathForBackup(c, db, is_incremental, full_backup_only, backup_bucket, backup_prefix)
        if backup_info.path:
            query_options["db"] = db
            if not full_backup_only:
                query_options["mode"] = "DIFFERENTIAL" if backup_info.is_incremental else "INIT"
            query_options["path"] = backup_info.path
            logging.info(query_template.format(credentials="<redacted>", **query_options))
            c.execute(query_template.format(credentials=json.dumps(backup_creds), **query_options))
            c.fetchall()
            if full_backup_only:
                logging.info("Finished full backup of database `{}` at {}".format(db, backup_info.path))
            else:
                logging.info("Finished {} backup of database `{}` at {}".format(query_options["mode"], db, backup_info.path))

    logging.info("Done")

if __name__ == "__main__":
    main()
