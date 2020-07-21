#!/usr/bin/python3

import logging
import util

def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
    )

    logging.info("Starting Drop User Job")

    # get config
    username_to_drop = util.must_get_env("USERNAME")

    # drop user
    logging.info("Dropping User {}".format(username_to_drop))
    conn = util.connect_memsql()
    util.drop_user(conn, username_to_drop)

    logging.info("Done!")

if __name__ == "__main__":
    main()
