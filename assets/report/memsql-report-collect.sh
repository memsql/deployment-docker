#!/bin/bash
set -euxo pipefail

# Local vars. others are inherited
unset AWS_CMD CHECK_REPORT_FILE

AWS_CMD="$(getAWS_command)"
if [[ -z ${AWS_CMD} ]]; then
    echo ERROR: cannot find AWS cli
    exit 1
fi

sdb-report collect-kube -c "${TB_CONFIG}" -o "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz"

# copy out before checking because to support a failed check we need to see the report
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/${CLUSTER_NAME}.tar.gz"

cat <<EOF > "${RESULT_DIR}/metadata.txt"
cluster_name: "${CLUSTER_NAME}"
created_at: "$(date)"
EOF
${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/metadata.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/metadata.txt"

# only perform checks for Admin reports and command line users who do not specify REPORT_TYPE
if [[ "${REPORT_TYPE}" = "Admin" ]] || [[ "$REPORT_TYPE" = "" ]]; then
    CHECK_REPORT_FILE="${RESULT_DIR}/${CLUSTER_NAME}.txt"
    echo "Internal: Will write check report to ${CHECK_REPORT_FILE}"
    sdb-report check -c "${TB_CONFIG}" -i "${RESULT_DIR}/${CLUSTER_NAME}.tar.gz" | tee "${CHECK_REPORT_FILE}" || echo "WARNING: CHECKS FAILED"
    ${AWS_CMD} s3 ${ENDPOINT_FLAG} cp "${RESULT_DIR}/${CLUSTER_NAME}.txt" "s3://${S3_REPORT_BUCKET}/${S3_REPORT_PATH}/check.txt"
fi
