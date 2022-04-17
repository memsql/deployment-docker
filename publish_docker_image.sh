#!/usr/bin/env bash

set -euxo pipefail

# The arguments to this script are a list of list image names
# to be published. e.g.:
#
# ./publish_docker_image.sh singlestore/node:${NODE_TAG} memsql/node:${NODE_TAG}
#
# This script will only publish each image if it isn't already
# present in remote.

for var in "$@"
do
    if docker manifest inspect ${var} ; then
        echo "Image already present in registry, not re-publishing."
    else
        echo "Image not found in registry, publishing."
        # docker push $var
    fi
done

