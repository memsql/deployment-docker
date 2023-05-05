#!/bin/bash

set -euxo pipefail

echo "$0 $* starting at $(date)"

if [[ $(which aws) = "" ]]; then
    echo  ERROR: unix util aws is not installed
    exit 1
fi

if [[ $(which sdb-report) = "" ]]; then
    echo  ERROR: unix util sdb-report is not installed
    exit 1
fi

# mandatory variables
echo CLUSTER_NAME=${CLUSTER_NAME}
echo S3_REPORT_BUCKET=${S3_REPORT_BUCKET}
echo S3_REPORT_PATH=${S3_REPORT_PATH}

# optional variables
REPORT_TYPE=${REPORT_TYPE:-""}
COLLECTOR_SUBSET=${COLLECTOR_SUBSET:-""}
OTHER_FLAGS=${OTHER_FLAGS:-""}
REPORT_TIMEOUT=${REPORT_TIMEOUT:-"60"}
S3_REPORT_ENDPOINT=${S3_REPORT_ENDPOINT:-""}

COLLECT_ONLY=${COLLECT_ONLY:-""}

if [[ "${COLLECT_ONLY}" != "" ]]; then
    COLLECTOR_FLAGS="--only ${COLLECT_ONLY}"
else
    # if REPORT_TYPE is not set (command line users), then we provide a full report
    # or if no collectors are specified
    if [[ "${REPORT_TYPE}" = "" ]] || [[ "${COLLECTOR_SUBSET}" = "" ]]; then
        COLLECTOR_FLAGS=""
    # if REPORT_TYPE=Admin, we provide a full report plus all specified collectors
    elif [[ "${REPORT_TYPE}" = "Admin" ]]; then
        COLLECTOR_FLAGS="--include ${COLLECTOR_SUBSET}"
    # if REPORT_TYPE=CUSTOMER, we provide only all specified collectors
    else
        COLLECTOR_FLAGS="--only ${COLLECTOR_SUBSET}"
    fi
fi

# the endpoint flag is set when we are given a report endpoint
if [[ "${S3_REPORT_ENDPOINT}" != "" ]]; then
    ENDPOINT_FLAG="--endpoint-url ${S3_REPORT_ENDPOINT}"
else
    ENDPOINT_FLAG=""
fi

REPORT_DIR=$(mktemp -d)
RESULT_DIR=$(mktemp -d)

timeout -k 5 ${REPORT_TIMEOUT} sdb-report collect-kube ${COLLECTOR_FLAGS} ${OTHER_FLAGS} --cluster-name ${CLUSTER_NAME} --version v1 --shard-queries --disable-colors --disable-spinner -vvv -o "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" --opt memsqlTracelogs.tracelogSize=100mb

# copy out before checking because to support a failed check we need to see the report
aws s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/report.tar.gz"

cat <<EOF > "${RESULT_DIR}/metadata.txt"
cluster_name: "${CLUSTER_NAME}"
created_at: "$(date)"
EOF
aws s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/metadata.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/metadata.txt"

# only perform checks for Admin reports and command line users who do not specify REPORT_TYPE
if [[ "${REPORT_TYPE}" = "Admin" ]] || [[ "$REPORT_TYPE" = "" ]]; then
    CHECK_REPORT_FILE="${RESULT_DIR}/${CLUSTER_NAME}.txt"
    echo "Internal: Will write check report to ${CHECK_REPORT_FILE}"
    sdb-report check -i "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" --exclude swapEnabled,minFreeKbytes,vmSwappiness | tee "${CHECK_REPORT_FILE}" || echo "WARNING: CHECKS FAILED"
    aws s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/check.txt"
fi
