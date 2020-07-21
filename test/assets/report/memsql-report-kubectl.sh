#!/bin/bash
set -euxo pipefail

# This is a replacement for the production script of the same name.
# To use this you must enable the local-dev minio plugin script for init-local-dev.
# To use temporarily overwrite the prod script in ../../../assets/report
# DO NOT CHECK IT INTO THE PROD TREE

cd /report
source cluster-report-lib.sh

# Replace the AWS command function with one for the local minio S3 store.

function getAWS_command() {
    MINIOPOD=$(kubectl get pod -l app=minio -o custom-columns=NAME:.metadata.name| sed 1d)
    if [ -n "${MINIOPOD}" ]; then
        # exists
        endpoint=$(kubectl describe pod ${MINIOPOD} | grep "IP:" | awk '{print $2;}')
        ENDPOINT_URL="--endpoint-url http://$endpoint:9000"
        echo Minio ENDPOINT_URL is $ENDPOINT_URL>&2
    fi
    echo "aws ${ENDPOINT_URL}"
}

export -f getAWS_command

exec /report/memsql-report-main.sh
