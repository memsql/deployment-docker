#!/bin/bash
set -euxo pipefail

# We expect these environment vars set:
#
echo CLUSTER_NAME=${CLUSTER_NAME}
echo S3_REPORT_BUCKET=${S3_REPORT_BUCKET}
echo S3_REPORT_PATH=${S3_REPORT_PATH}
echo AWS_REGION=${AWS_REGION}
echo PODS=${PODS}
echo CLUSTER_COLLECTION_SCRIPT=${CLUSTER_COLLECTION_SCRIPT}

REPORT_TIMEOUT=${REPORT_TIMEOUT:-"60"}

# Local variables init
unset TB_CONFIG FAILED_PODS_LIST REPORT_DIR RESULT_DIR CMD FAILED_PODS

TB_CONFIG="/tmp/tb_config"
FAILED_PODS_LIST=$(mktemp)
REPORT_DIR=$(mktemp -d)
RESULT_DIR=$(mktemp -d)

echo 'user="root"' > ${TB_CONFIG}

export TB_CONFIG FAILED_PODS_LIST REPORT_DIR RESULT_DIR CMD

export FAILED_PODS="$(cat $FAILED_PODS_LIST)"
rm -f "$FAILED_PODS_LIST"

# Collect reports from the cluster and collate
if [[ -f "${CLUSTER_COLLECTION_SCRIPT}" ]]; then
    ${CLUSTER_COLLECTION_SCRIPT}
fi
