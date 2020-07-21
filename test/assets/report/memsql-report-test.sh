#!/bin/bash
set -euxo pipefail

# This is the mainline for local testing of report script code flow.
# This only tests logic and does not produce a report.

echo START REPORT TEST

# Make a weak attempt at spoofing the prod bash environment
if [[ ! -v CLUSTER_NAME ]]; then export CLUSTER_NAME="VAR_CLUSTER_NAME_$RANDOM"; fi
if [[ ! -v S3_REPORT_BUCKET ]]; then export S3_REPORT_BUCKET="VAR_S3_REPORT_BUCKET_$RANDOM"; fi
if [[ ! -v S3_REPORT_PATH ]]; then export S3_REPORT_PATH="VAR_S3_REPORT_PATH_$RANDOM"; fi
if [[ ! -v AWS_ACCESS_KEY_ID ]]; then export AWS_ACCESS_KEY_ID="VAR_AWS_ACCESS_KEY_ID_$RANDOM"; fi
if [[ ! -v AWS_SECRET_ACCESS_KEY ]]; then export AWS_SECRET_ACCESS_KEY="VAR_AWS_SECRET_ACCESS_KEY_$RANDOM"; fi
if [[ ! -v AWS_REGION ]]; then export AWS_REGION="VAR_AWS_REGION_$RANDOM"; fi

# Be explicit about what we are passing to main in addition to the ones that came into this process already (listed above)
unset TEST_PARALLELISM TEST_PODS PODS LOCAL_COLLECTION_SCRIPT CLUSTER_COLLECTION_SCRIPT MEMSQL_TEST_REPORT_HOME

export TEST_PODS="test-pod-1,test-pod-2,test-pod-3,test-pod-4"

# Degree of Parallelism for testing (less than prod so that is can be observed)
TMP=($(cut -d"," --output-delimiter=" " -f1- <<< "${TEST_PODS}"))
POD_COUNT=${#TMP[@]}
echo POD_COUNT=${POD_COUNT}
# Max parallelism of 4x CPU, or reduce if less pods.
((TEST_PARALLELISM=$(nproc)/4))
echo TEST_PARALLELISM=${TEST_PARALLELISM}
if [[ POD_COUNT -lt TEST_PARALLELISM ]]; then TEST_PARALLELISM=${POD_COUNT}; fi
echo TEST_PARALLELISM=${TEST_PARALLELISM}
export TEST_PARALLELISM


# set up for test run of code path only

function getParallelism() { echo "${TEST_PARALLELISM}"; }
function getPods() { echo "$TEST_PODS"; }
function getLocal_collection_script() { echo "${MEMSQL_TEST_REPORT_HOME}/memsql-report-test-local.sh"; }
function getCluster_collection_script() { echo "${MEMSQL_TEST_REPORT_HOME}/memsql-report-test-cluster.sh"; }
function getAWS_command() { echo "echo AWS support disabled for test "; }

# Be explicit about what we are exporting to the main cluster report code
export MEMSQL_TEST_REPORT_HOME="$(pwd)"
export -f getParallelism getPods getLocal_collection_script getCluster_collection_script getAWS_command

# move to the prod code
pushd ../../../assets/report
./memsql-report-main.sh

# return to test tree
popd

echo END REPORT TEST

