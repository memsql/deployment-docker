#!/bin/bash
set -euxo pipefail

# Local vars. others are inherited
unset OPERATOR_POD AWS_CMD CHECK_REPORT_FILE
OPERATOR_POD="$(getOperator_pod)"

AWS_CMD="$(getAWS_command)"
if [[ -z ${AWS_CMD} ]]; then
    echo ERROR: cannot find AWS cli
    exit 1
fi

memsql-report collect -c "${TB_CONFIG}" --merge-path "${REPORT_DIR}" -o "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz"

# copy out before checking because to support a failed check we need to see the report
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/report.tar.gz"

cat <<EOF > "${RESULT_DIR}/metadata.txt"
cluster_name: "${CLUSTER_NAME}"
created_at: "$(date)"
EOF
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/metadata.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/metadata.txt"

# We only want to collect operator logs and perform checks for Admin reports
if [[ "${REPORT_TYPE}" = "Admin" ]]; then
# Collect operator logs
    if [[ -n "${OPERATOR_POD}" ]]; then
        OPERATOR_LOG="${RESULT_DIR}/operator.log"
        if [[ -f "${OPERATOR_LOG}" ]]; then rm -f "${OPERATOR_LOG}"; fi
        kubectl log "${OPERATOR_POD}" >"${OPERATOR_LOG}"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${OPERATOR_LOG}" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/operator.log"
    else
        echo "ERROR CANNOT FIND OPERATOR POD" >&2
        exit 1
    fi

    CHECK_REPORT_FILE="${RESULT_DIR}/${CLUSTER_NAME}.txt"
    echo "Internal: Will write check report to {$CHECK_REPORT_FILE}"
    memsql-report check -c "${TB_CONFIG}" -i "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" | tee "${CHECK_REPORT_FILE}" || echo "WARING: CHECKS FAILED"
    ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/check.txt"

    if [[ -v FAILED_PODS && -n "${FAILED_PODS}" ]]
    then
        echo "Failed to collect reports from the following pods: ${FAILED_PODS}" > "${RESULT_DIR}/noCollect.txt"
        ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/noCollect.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/noCollect.txt"
        exit 1
    fi
fi

