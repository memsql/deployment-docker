#!/bin/bash
set -euxo pipefail

# We expect these environment vars set:
#
echo CLUSTER_NAME=${CLUSTER_NAME}
echo S3_REPORT_BUCKET=${S3_REPORT_BUCKET}
echo S3_REPORT_PATH=${S3_REPORT_PATH}
echo AWS_REGION=${AWS_REGION}
echo PARALLELISM=${PARALLELISM}
echo PODS=${PODS}
echo STATEFULSETS=${STATEFULSETS}
echo SERVICES=${SERVICES}
echo PVCS=${PVCS}
echo LOCAL_COLLECTION_SCRIPT=${LOCAL_COLLECTION_SCRIPT}
echo CLUSTER_COLLECTION_SCRIPT=${CLUSTER_COLLECTION_SCRIPT}

function run_parallel() {
    echo "Running parallel command at PARALLELISM=${PARALLELISM}"
    if [ -f $FAILED_PODS_LIST ]; then rm -f "${FAILED_PODS_LIST}"; fi
    touch "$FAILED_PODS_LIST"
	echo -n "$PODS" | xargs -d"," -t -n 1 -P ${PARALLELISM} -I _POD_ bash -c "timeout -k 5 60 $CMD || echo _POD_ >> ${FAILED_PODS_LIST}"
}

# Local variables init
unset TB_CONFIG FAILED_PODS_LIST REPORT_DIR RESULT_DIR CMD FAILED_PODS

TB_CONFIG="/tmp/tb_config"
FAILED_PODS_LIST=$(mktemp)
REPORT_DIR=$(mktemp -d)
RESULT_DIR=$(mktemp -d)

echo 'user="root"' > ${TB_CONFIG}

# Is run against every pod in parallel
CMD="${LOCAL_COLLECTION_SCRIPT}"' _POD_ '"${REPORT_DIR}"

export TB_CONFIG FAILED_PODS_LIST REPORT_DIR RESULT_DIR CMD
# log these to STDOUT
echo "TB_CONFIG=${TB_CONFIG} FAILED_PODS_LIST=${FAILED_PODS_LIST} REPORT_DIR=${REPORT_DIR} RESULT_DIR=${RESULT_DIR} CMD=$CMD"

run_parallel

export FAILED_PODS="$(cat $FAILED_PODS_LIST)"
rm -f "$FAILED_PODS_LIST"

# Collect reports from the cluster and collate
if [[ -f "${CLUSTER_COLLECTION_SCRIPT}" ]]; then
    ${CLUSTER_COLLECTION_SCRIPT}
fi
