#!/usr/bin/python3

import logging
import util

def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
    )

    logging.info("Starting Create User Job")

    # get config
    username_to_create = util.must_get_env("USERNAME")
    password_to_create = util.must_get_env("PASSWORD")
    privacy_sensitive = util.get_env("PRIVACY_SENSITIVE", "false").lower() == "true"

    # create user and grant super privileges
    logging.info("Creating User {}".format(username_to_create))
    conn = util.connect_memsql()
    util.create_user(conn, username_to_create, password_to_create)
    util.grant_user_service_user(conn, username_to_create)
    if privacy_sensitive:
        util.grant_user_show_metadata(conn, username_to_create)
        util.grant_user_show_pipeline(conn, username_to_create)
        util.grant_user_process(conn, username_to_create)
        util.grant_user_super(conn, username_to_create)
        util.grant_user_cluster(conn, username_to_create)
    else:
        util.grant_user_all(conn, username_to_create)

    logging.info("Done!")

if __name__ == "__main__":
    main()
