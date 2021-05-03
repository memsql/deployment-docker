#!/bin/bash
set -euxo pipefail

echo "$0 $* starting at $(date)"

# log these variables
declare | grep S3
declare | grep AWS | grep -v KEY

# Varify these environment vars set. If they are not the script will abort.
# (referencing them here forces bash to check them)
echo CLUSTER_NAME=${CLUSTER_NAME}
echo S3_REPORT_BUCKET=${S3_REPORT_BUCKET}
echo S3_REPORT_PATH=${S3_REPORT_PATH}
echo AWS_REGION=${AWS_REGION}

# Local variables init
unset FAILED_PODS_LIST CLUSTER_COLLECTION_SCRIPT

export PODS=$(getPods)
export CLUSTER_COLLECTION_SCRIPT=$(getCluster_collection_script)

# Validate these are not null
if [[ -z $PODS || -z CLUSTER_COLLECTION_SCRIPT ]]; then
    echo ERROR - required values missing. please check environment.
    exit 1
fi

# command line users do not have to provide these args
REPORT_TYPE=${REPORT_TYPE:-""}
COLLECTOR_SUBSET=${COLLECTOR_SUBSET:-""}
LOG_DURATION=${LOG_DURATION:-"0"}

export REPORT_TYPE
export COLLECTOR_SUBSET
export LOG_DURATION

# if REPORT_TYPE is not set (command line users), then we provide a full report
# or if no collectors are specified
if [[ "${REPORT_TYPE}" = "" ]] || [[ "${COLLECTOR_SUBSET}" = "" ]]; then
    export COLLECTOR_FLAGS=""
# if REPORT_TYPE=Admin, we provide a full report plus all specified collectors
elif [[ "${REPORT_TYPE}" = "Admin" ]]; then
    export COLLECTOR_FLAGS="--include ${COLLECTOR_SUBSET}"
# if REPORT_TYPE=CUSTOMER, we provide only all specified collectors
else
    export COLLECTOR_FLAGS="--only ${COLLECTOR_SUBSET}"
fi

# default no endpoint
S3_REPORT_ENDPOINT=${S3_REPORT_ENDPOINT:-""}

# the endpoint flag is set when we are given a report endpoint
if [[ "${S3_REPORT_ENDPOINT}" != "" ]]; then
    export ENDPOINT_FLAG="--endpoint-url ${S3_REPORT_ENDPOINT}"
else 
    export ENDPOINT_FLAG=""
fi

export REPORT_TIMEOUT=${REPORT_TIMEOUT:-"60"}

./memsql-report-distributed.sh

