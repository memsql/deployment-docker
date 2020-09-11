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
unset FAILED_PODS_LIST PARALLELISM LOCAL_COLLECTION_SCRIPT CLUSTER_COLLECTION_SCRIPT

export PARALLELISM=$(getParallelism)
export PODS=$(getPods)
export LOCAL_COLLECTION_SCRIPT=$(getLocal_collection_script)
export CLUSTER_COLLECTION_SCRIPT=$(getCluster_collection_script)

# Validate these are not null
if [[ -z $PARALLELISM || -z $PODS || -z LOCAL_COLLECTION_SCRIPT || -z CLUSTER_COLLECTION_SCRIPT ]]; then
    echo ERROR - required values missing. please check environment.
    exit 1
fi

# default to providing a full admin report if not specified
REPORT_TYPE=${REPORT_TYPE:-"Admin"}

COLLECTOR_SUBSET=${COLLECTOR_SUBSET:-""}

# only look at the COLLECTOR_SUBSET flag if REPORT_TYPE != "Admin"
if [[ "${REPORT_TYPE}" = "Admin" ]] || [[ "${COLLECTOR_SUBSET}" = "" ]]; then
    # all collectors
    export COLLECTOR_FLAGS=""
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

./memsql-report-distributed.sh

