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

function getPods() {
    PODS="$(kubectl get POD -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $PODS | sed -e's/\s\+/,/g');
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

function getOperator_pod () { 
    OP=$(kubectl get pod -l app.kubernetes.io/component=operator,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)
    if [[ -n "${OP}" ]]; then
        echo "${OP}"
    else
        echo "ERROR FINDING OPERATOR POD">&2
        return 1
    fi
}

export -f getParallelism getPods getLocal_collection_script getCluster_collection_script getAWS_command getOperator_pod

