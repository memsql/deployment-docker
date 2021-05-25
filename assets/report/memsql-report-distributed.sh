#!/bin/bash
set -euxo pipefail

# We expect these environment vars set:
#
echo CLUSTER_NAME=${CLUSTER_NAME}
echo S3_REPORT_BUCKET=${S3_REPORT_BUCKET}
echo S3_REPORT_PATH=${S3_REPORT_PATH}
echo AWS_REGION=${AWS_REGION}
echo CLUSTER_COLLECTION_SCRIPT=${CLUSTER_COLLECTION_SCRIPT}

REPORT_TIMEOUT=${REPORT_TIMEOUT:-"60"}

# Local variables init
unset TB_CONFIG REPORT_DIR RESULT_DIR CMD

TB_CONFIG="/tmp/tb_config"
REPORT_DIR=$(mktemp -d)
RESULT_DIR=$(mktemp -d)

echo 'user="root"' > ${TB_CONFIG}

export TB_CONFIG REPORT_DIR RESULT_DIR CMD

# Collect reports from the cluster and collate
if [[ -f "${CLUSTER_COLLECTION_SCRIPT}" ]]; then
    ${CLUSTER_COLLECTION_SCRIPT}
fi
