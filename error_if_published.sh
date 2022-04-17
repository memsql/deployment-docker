#!/usr/bin/env bash

set -euxo pipefail

# The arguments to this script are a list of list image names
# to be published. e.g.:
#
# ./error_if_published.sh singlestore/node:${NODE_TAG} memsql/node:${NODE_TAG} ...
#
# This script will "exit 1" if all of the images are already published.
# This allows the rest of the code to be skipped. It's a bit hacky.

# This is needed for `docker manifest` to work.
# export DOCKER_CLI_EXPERIMENTAL=enabled

docker version

exit_code=1
for var in "$@"
do
    if docker manifest inspect ${var} ; then
        echo "Image already present in registry, not re-publishing."
    else
        echo "Image not found in registry, publishing."
        exit_code=0
    fi
done

exit ${exit_code}