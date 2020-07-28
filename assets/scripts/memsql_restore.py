#!/usr/bin/python3

import logging
import json
from os import getenv
import util

def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)-15s: %(levelname)-8s: %(message)s")
    logging.info("running restore job... ")

    # Get the AWS credentials from the environment
    backup_creds = {}
    backup_creds["aws_access_key_id"] = util.must_get_env("AWS_ACCESS_KEY")
    backup_creds["aws_secret_access_key"] = util.must_get_env("AWS_SECRET_ACCESS_KEY", True)

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
            logging.error("Invalid Environment Variable Found for COMPATIBILITY_MODE: {}".format(compatibility_mode))
            exit(1)

    # Get the backup name details
    backup_path = util.must_get_env("MEMSQL_BACKUP_PATH_NAME")
    backup_bucket = util.must_get_env("MEMSQL_BACKUP_BUCKET")
    db_names = util.must_get_env("MEMSQL_BACKUP_DATABASE_NAMES").split(",")

    # Connect to the target cluster
    logging.info("Connecting to target cluster")
    db = util.connect_memsql()
    logging.info("Connected to target cluster")
    c = db.cursor()

    # Run the restore
    logging.info("Attempting to restore these databases: {}".format(db_names))
    query_template = "RESTORE DATABASE `{db}` FROM S3 \"{bucket}/{path}\" CONFIG '{config}' CREDENTIALS '{credentials}'"
    query_options = {}
    query_options["bucket"] = backup_bucket
    query_options["path"] = backup_path
    query_options["config"] = json.dumps(backup_config)
    for db in db_names:
        query_options["db"] = db
        logging.info(query_template.format(credentials="<redacted>", **query_options))
        c.execute(query_template.format(credentials=json.dumps(backup_creds), **query_options))
        c.fetchall()
        logging.info("Finished restore of database `{}`".format(db))

    logging.info("Done")

if __name__ == "__main__":
    main()
