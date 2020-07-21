#!/usr/bin/python2.7
#
# Optional arguments
#
# --sync        Run sync_snapshot before exiting to wait until the snapshot(s) complete

import logging
import json
from os import getenv
from sys import exit, stdout
import time
import argparse

import MySQLdb

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)-15s: %(levelname)-8s: %(message)s",
    stream=stdout)

PARSER = argparse.ArgumentParser()
PARSER.add_argument(
    "--sync",
    dest="sync",
    action='store_true',
    help="synchronize snapshots before exiting")
ARGS = PARSER.parse_args()

logging.info("args: {}".format(ARGS))

def get_env_or_fail(var, redact_log=False):
    val = getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        exit(1)
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val


if __name__ == "__main__":

    # Get the database connection information from the environment
    memsql_hostname = get_env_or_fail("MEMSQL_HOSTNAME")

    memsql_user = getenv("MEMSQL_USERNAME", "root")
    logging.info("Using username \"{}\"".format(memsql_user))

    memsql_password = get_env_or_fail("MEMSQL_PASSWORD", True)

    logging.info("Connecting to target cluster")

    # Connect to the target cluster
    db = MySQLdb.connect(host=memsql_hostname, user=memsql_user, passwd=memsql_password)

    logging.info("Connected to target cluster, retrieving database list")

    # Get the list of databases
    c = db.cursor()
    c.execute("SELECT DATABASE_NAME FROM INFORMATION_SCHEMA.DISTRIBUTED_DATABASES")
    dbs = map(lambda x: x[0], c.fetchall())

    logging.info("Found {} databases".format(len(dbs)))

    def run_sql_command(query_template):
        for db in dbs:
            query = query_template % db
            logging.info(query)
            c.execute(query)

    run_sql_command("SNAPSHOT DATABASE %s")

    if ARGS.sync:
        run_sql_command("SYNC_SNAPSHOT %s")

    logging.info("Done")

