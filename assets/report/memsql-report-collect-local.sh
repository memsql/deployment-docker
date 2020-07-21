#!/bin/bash
set -euxo pipefail

POD=$1
REPORT_DIR=$2

# We expect these environment vars set:
# S3_REPORT_BUCKET

# lock the pod via annotation
# trying to set an annotation where the key already exists will fail
kubectl annotate pod ${POD} memsql-report-lock-owner=${S3_REPORT_PATH}

function cleanup {
    kubectl exec ${POD} -- bash -c 'rm -rf /tmp/report' || true
    # adding - to the annotation key will make this delete that annotation
    kubectl annotate pod ${POD} memsql-report-lock-owner-
}
trap cleanup EXIT

kubectl exec ${POD} -- bash -c 'rm -rf /tmp/report'
kubectl exec ${POD} -- bash -c 'mkdir /tmp/report'

kubectl cp $(which memsql-report) ${POD}:tmp/report/memsql-report
# support running reports for root and non-root users
kubectl exec ${POD} -- bash -c 'export USER=$(whoami) && echo user=\"${USER}\" > /tmp/report/tb_config';
# we set XDG_DATA_HOME because reports tries to create a directory there and
# it defaults to $HOME/.local/... which non-root users do not have write permission
kubectl exec ${POD} -- bash -c 'export XDG_DATA_HOME=/tmp/report && /tmp/report/memsql-report collect-local -c /tmp/report/tb_config -o /tmp/report/report.tar.gz --opt memsqlTracelogs.tracelogSize=100mb --hostname '${POD}''
# remove leading slash from temp_dir for kubectl cp
kubectl cp ${POD}:tmp/report/report.tar.gz ${REPORT_DIR}/${POD}
