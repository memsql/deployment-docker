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


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)-15s: %(levelname)-8s: %(message)s")

    # Get the AWS credentials from the environment
    backup_creds = {}
    backup_creds["aws_access_key_id"] = GetenvOrFail("AWS_ACCESS_KEY")
    backup_creds["aws_secret_access_key"] = GetenvOrFail("AWS_SECRET_ACCESS_KEY", True)

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

    # Name the backup
    backup_prefix = GetenvOrFail("MEMSQL_BACKUP_NAME")
    timestamp = time.strftime("%Y-%m-%d-%H-%M", time.gmtime())
    backup_base_name = "{}_{}".format(backup_prefix, timestamp)

    backup_bucket = GetenvOrFail("MEMSQL_BACKUP_BUCKET")

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
    query_template = "BACKUP DATABASE `{db}` TO S3 \"{bucket}/{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"
    query_options = {}
    query_options["bucket"] = backup_bucket
    query_options["path"] = backup_base_name
    query_options["config"] = json.dumps(backup_config)
    for db in dbs:
        query_options["db"] = db
        logging.info(query_template.format(credentials="<redacted>", **query_options))
        c.execute(query_template.format(credentials=json.dumps(backup_creds), **query_options))
        c.fetchall()
        logging.info("Finished backup of database `{}`".format(db))

    logging.info("Done")
