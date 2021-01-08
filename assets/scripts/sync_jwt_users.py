#!/usr/bin/python3

import logging
import util

def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
    )

    logging.info("Starting Sync Users Job")

    # connect cluster
    logging.info("Connecting to target cluster")
    db = util.connect_memsql()
    logging.info("Connected to target cluster")

    # inputs
    expected_users_list = util.must_get_env("JWT_USERS_LIST")
    expected_users = set()
    if expected_users_list != '':
        expected_users = set(expected_users_list.split(","))
    logging.info("expected list of jwt users: {}".format(expected_users))

    expected_permissions_list = util.must_get_env("PERMISSIONS")
    expected_permissions = set()
    if expected_permissions_list != '':
        expected_permissions = set(expected_permissions_list.split(","))
    logging.info("expected list of permissions: {}".format(expected_permissions))

    # get current list of JWT users
    actual_users = util.list_jwt_users(db)
    logging.info("current list of jwt users: {}".format(actual_users))

    # create expected user if it does not exist
    # do not require ssl if cluster is using http proxy port
    http_proxy_port = util.get_variable(db, "http_proxy_port")
    for expected_user in expected_users:
        if expected_user not in actual_users:
            if int(http_proxy_port) > 0:
                logging.info("Creating JWT user {}".format(expected_user))
                util.create_jwt_user(db, expected_user)
            else:
                logging.info("Creating JWT user {} with REQUIRE SSL".format(expected_user))
                util.create_jwt_user_ssl(db, expected_user)

    # drop users that are not expected
    for actual_user in actual_users:
        if actual_user not in expected_users:
            logging.info("Dropping JWT user {}".format(actual_user))
            util.drop_user(db, actual_user)

    # grant all expected users permissions
    for expected_user in expected_users:
        util.grant_user_permissions(db, expected_user, expected_permissions_list, "*.*")
    logging.info("Done!")

if __name__ == "__main__":
    main()
