# Common utilities

import logging
import pymysql
import os

def get_env(var, default, redact_log=False):
    val = os.getenv(var)
    if val is None:
        val = default
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val

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

def grant_user_service_user(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("SHOW GRANTS")
        grants = cursor.fetchone()[0]
        # if root has SERVICE_USER, grant SERVICE_USER to support account
        if "SERVICE_USER" in grants:
            cursor.execute("GRANT SERVICE_USER ON *.* TO %s", (username,))
            logging.info("GRANT SERVICE_USER ON *.* TO {}".format(username))

def grant_user_show_metadata(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT SHOW METADATA ON *.* TO %s", (username,))

def grant_user_show_pipeline(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT SHOW PIPELINE ON *.* TO %s", (username,))

def grant_user_process(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT PROCESS ON *.* TO %s", (username,))

def grant_user_super(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT SUPER ON *.* TO %s", (username,))

def grant_user_cluster(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT CLUSTER ON *.* TO %s", (username,))

def grant_user_all(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("GRANT ALL ON *.* TO %s", (username,))

def grant_user_permissions(conn, username, permissions, scope):
    with conn.cursor() as cursor:
        cursor.execute("GRANT {} ON {} TO %s".format(permissions, scope), (username,))

def drop_user(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("DROP USER %s", (username,))

def create_jwt_user_ssl(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("CREATE USER %s IDENTIFIED WITH authentication_jwt REQUIRE SSL", (username,))

def create_jwt_user(conn, username):
    with conn.cursor() as cursor:
        cursor.execute("CREATE USER %s IDENTIFIED WITH authentication_jwt", (username,))

def list_jwt_users(conn):
    users = set()
    # DB-47423, use WHERE clause
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM INFORMATION_SCHEMA.USERS")
        rows = cursor.fetchall()
        for row in rows:
            if row[2] == 'JWT':
                users.add(row[0])
    return users

def get_variable(conn, variable_name):
   with conn.cursor() as cursor:
        cursor.execute("SHOW VARIABLES LIKE %s", (variable_name))
        rows = cursor.fetchall()
        for row in rows:
            if row[0] == variable_name:
                return row[1]
   raise Exception("Engine variable `%s` cannot be found".format(variable_name))

