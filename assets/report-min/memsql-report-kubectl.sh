#!/bin/bash

set -euxo pipefail

echo "$0 $* starting at $(date)"

if [[ $(which sdb-report) = "" ]]; then
    echo  ERROR: unix util sdb-report is not installed
    exit 1
fi

# mandatory variables
echo CLUSTER_NAME=${CLUSTER_NAME}

# optional variables
REPORT_TYPE=${REPORT_TYPE:-""}
COLLECTOR_SUBSET=${COLLECTOR_SUBSET:-""}
OTHER_FLAGS=${OTHER_FLAGS:-""}
REPORT_TIMEOUT=${REPORT_TIMEOUT:-"60"}

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


RESULT_DIR=$(mktemp -d)

timeout -k 5 ${REPORT_TIMEOUT} sdb-report collect-kube ${COLLECTOR_FLAGS} ${OTHER_FLAGS} --cluster-name ${CLUSTER_NAME} --version v1 --shard-queries --disable-colors --disable-spinner -vvv -o "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" --opt memsqlTracelogs.tracelogSize=100mb

cat <<EOF > "${RESULT_DIR}/metadata.txt"
cluster_name: "${CLUSTER_NAME}"
created_at: "$(date)"
EOF

# only perform checks for Admin reports and command line users who do not specify REPORT_TYPE
if [[ "${REPORT_TYPE}" = "Admin" ]] || [[ "$REPORT_TYPE" = "" ]]; then
    CHECK_REPORT_FILE="${RESULT_DIR}/${CLUSTER_NAME}.txt"
    echo "Internal: Will write check report to ${CHECK_REPORT_FILE}"
    sdb-report check -i "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" --exclude swapEnabled,minFreeKbytes,vmSwappiness | tee "${CHECK_REPORT_FILE}" || echo "WARNING: CHECKS FAILED"
fi
