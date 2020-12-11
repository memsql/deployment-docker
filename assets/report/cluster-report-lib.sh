if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "MUST BE SOURCED!"; exit 1; fi

# Define functions to control how reports are run on the cluster

function getParallelism() {
    # Max parallelism of 4x CPU, or reduce if fewer pods.
    ((_PARALLELISM=$(nproc)*4))
    TMP=($(cut -d"," --output-delimiter=" " -f1- <<< "$(getPods)"))
    POD_COUNT=${#TMP[@]}
    if [[ POD_COUNT -lt _PARALLELISM ]]; then _PARALLELISM=${POD_COUNT}; fi
    echo "${_PARALLELISM}"
}

# getResource functions return comma-separated values
function getPods() {
    PODS="$(kubectl get POD -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $PODS | sed -e's/\s\+/,/g');
}

function getStatefulSets() {
    STATEFULSETS="$(kubectl get STATEFULSET -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $STATEFULSETS | sed -e's/\s\+/,/g');
}

function getServices() {
    SERVICES="$(kubectl get SERVICE -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $SERVICES | sed -e's/\s\+/,/g');
}

function getPVCs() {
    PVCS="$(kubectl get PERSISTENTVOLUMECLAIM -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $PVCS | sed -e's/\s\+/,/g');
}

function getLocal_collection_script() { echo "./memsql-report-collect-local.sh"; }

function getCluster_collection_script() { echo "./memsql-report-collect.sh"; }

function getAWS_command() {
    if [[ -n $(which aws) ]]; then
        echo "aws"
        return 0
    else
        echo "WARNING: aws cli not found">&2
        return 1
    fi
}

function getOperator_pod() { 
    OP=$(kubectl get pod -l app.kubernetes.io/component=operator,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)
    if [[ -n "${OP}" ]]; then
        echo "${OP}"
    else
        echo "ERROR FINDING OPERATOR POD">&2
        return 1
    fi
}

function getOperator_deployment() {
    OP=$(kubectl get deployment -l app.kubernetes.io/component=operator,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)
    if [[ -n "${OP}" ]]; then
        echo "${OP}"
    else
        echo "ERROR FINDING OPERATOR DEPLOYMENT">&2
        return 1
    fi
}

export -f getParallelism
export -f getPods
export -f getStatefulSets
export -f getServices
export -f getPVCs
export -f getLocal_collection_script
export -f getCluster_collection_script
export -f getAWS_command
export -f getOperator_pod
export -f getOperator_deployment
