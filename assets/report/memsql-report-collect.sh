#!/bin/bash
set -euxo pipefail

# Local vars. others are inherited
unset OPERATOR_POD OPERATOR_DEPLOYMENT AWS_CMD CHECK_REPORT_FILE
OPERATOR_POD="$(getOperator_pod)"
OPERATOR_DEPLOYMENT="$(getOperator_deployment)"

AWS_CMD="$(getAWS_command)"
if [[ -z ${AWS_CMD} ]]; then
    echo ERROR: cannot find AWS cli
    exit 1
fi

sdb-report collect -c "${TB_CONFIG}" --merge-path "${REPORT_DIR}" -o "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz"

# copy out before checking because to support a failed check we need to see the report
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/report.tar.gz"

cat <<EOF > "${RESULT_DIR}/metadata.txt"
cluster_name: "${CLUSTER_NAME}"
created_at: "$(date)"
EOF
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/metadata.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/metadata.txt"

# Set up noCollect log
NOCOLLECT="${RESULT_DIR}/noCollect.txt"


# only collect operator logs and perform checks for Admin reports and command line users who do not specify REPORT_TYPE
if [[ "${REPORT_TYPE}" = "Admin" ]] || [[ "$REPORT_TYPE" = "" ]]; then
    # Collect operator logs
    if [[ -n "${OPERATOR_POD}" ]]; then
        OPERATOR_LOG="${RESULT_DIR}/operator.log"
        if [[ -f "${OPERATOR_LOG}" ]]; then rm -f "${OPERATOR_LOG}"; fi
        kubectl log "${OPERATOR_POD}" --since "${LOG_DURATION}" > "${OPERATOR_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${OPERATOR_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/operator.log"
    else
        echo "ERROR CANNOT FIND OPERATOR POD" >> "${NOCOLLECT}"
    fi

    # Get Operator Deployment Config
    if [[ -n "${OPERATOR_DEPLOYMENT}" ]]; then
        OPERATOR_DEPLOY_CONFIG="${RESULT_DIR}/operator-deployment-config.yaml"
        if [[ -f "${OPERATOR_DEPLOY_CONFIG}" ]]; then rm -f "${OPERATOR_DEPLOY_CONFIG}"; fi
        kubectl get deployment "${OPERATOR_DEPLOYMENT}" -o yaml > "${OPERATOR_DEPLOY_CONFIG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${OPERATOR_DEPLOY_CONFIG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/operator-deployment-config.yaml"
    else
        echo "ERROR CANNOT FIND OPERATOR DEPLOYMENT" >> "${NOCOLLECT}"
    fi

    # Get SingleStore Cluster CR Config
    if [[ -n "${CLUSTER_NAME}" ]]; then
        MEMSQL_CLUSTER_CONFIG="${RESULT_DIR}/memsql-cluster-config.yaml"
        if [[ -f "${MEMSQL_CLUSTER_CONFIG}" ]]; then rm -f "${MEMSQL_CLUSTER_CONFIG}"; fi
        kubectl get memsql "${CLUSTER_NAME}" -o yaml > "${MEMSQL_CLUSTER_CONFIG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${MEMSQL_CLUSTER_CONFIG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/memsql-cluster-config.yaml"
    else
        echo "ERROR CANNOT FIND MEMSQL CLUSTER" >> "${NOCOLLECT}"
    fi

    # Get Statefulset Details
    if [[ -n "${STATEFULSETS}" ]]; then
        STATEFULSET_LOG="${RESULT_DIR}/statefulset.log"
        if [[ -f "${STATEFULSET_LOG}" ]]; then rm -f "${STATEFULSET_LOG}"; fi
        kubectl describe statefulsets $(echo $STATEFULSETS | sed -e 's/,/ /g') > "${STATEFULSET_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${STATEFULSET_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/statefulset.log"
    else
        echo "ERROR CANNOT FIND STATEFULSETS" >> "${NOCOLLECT}"
    fi

    # Get Pod Details
    if [[ -n "${PODS}" ]]; then
        POD_LOG="${RESULT_DIR}/pod.log"
        if [[ -f "${POD_LOG}" ]]; then rm -f "${POD_LOG}"; fi
        kubectl describe pods $(echo $PODS | sed -e 's/,/ /g') > "${POD_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${POD_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/pod.log"
    else
        echo "ERROR CANNOT FIND PODS" >> "${NOCOLLECT}"
    fi

    # Get Service Details
    if [[ -n "${SERVICES}" ]]; then
        SERVICE_LOG="${RESULT_DIR}/service.log"
        if [[ -f "${SERVICE_LOG}" ]]; then rm -f "${SERVICE_LOG}"; fi
        kubectl describe services $(echo $SERVICES | sed -e's/,/ /g') > "${SERVICE_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${SERVICE_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/service.log"
    else
        echo "ERROR CANNOT FIND SERVICES" >> "${NOCOLLECT}"
    fi

    # Get PVC Details
    if [[ -n "${PVCS}" ]]; then
        PVC_LOG="${RESULT_DIR}/pvc.log"
        if [[ -f "${PVC_LOG}" ]]; then rm -f "${PVC_LOG}"; fi
        kubectl describe persistentvolumeclaims $(echo $PVCS | sed -e's/,/ /g') > "${PVC_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${PVC_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/pvc.log"
    else
        echo "ERROR CANNOT FIND PVCS" >> "${NOCOLLECT}"
    fi


    CHECK_REPORT_FILE="${RESULT_DIR}/${CLUSTER_NAME}.txt"
    echo "Internal: Will write check report to ${CHECK_REPORT_FILE}"
    sdb-report check -c "${TB_CONFIG}" -i "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" | tee "${CHECK_REPORT_FILE}" || echo "WARING: CHECKS FAILED"
    ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/check.txt"

    if [[ -v FAILED_PODS && -n "${FAILED_PODS}" ]]
    then
        echo "Failed to collect reports from the following pods: ${FAILED_PODS}" >> "${NOCOLLECT}"
    fi
fi

if [[ -s "${NOCOLLECT}" ]]; then
    ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${NOCOLLECT}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/noCollect.txt"
fi
