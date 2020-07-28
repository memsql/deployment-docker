# Common utilities

import logging
import pymysql
import os

def must_get_env(var, redact_log=False):
    val = os.getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        raise Exception("Environment variable {} is required".format(var))
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val

def connect_memsql():
    return pymysql.connect(
        host=must_get_env("MEMSQL_HOSTNAME"),
        user=os.getenv("MEMSQL_USERNAME", "root"),
        password=must_get_env("MEMSQL_PASSWORD", True),
    )

def create_user(conn, username, password):
    with conn.cursor() as cursor:
        cursor.execute("CREATE USER %s IDENTIFIED BY PASSWORD %s", (
            username, password,
        ))

def grant_user_super(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT ALL ON *.* TO %s", (username,))

def drop_user(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("DROP USER %s", (username,))

