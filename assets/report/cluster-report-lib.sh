if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "MUST BE SOURCED!"; exit 1; fi

# Define functions to control how reports are run on the cluster

# getPods returns comma-separated values
function getPods() {
    PODS="$(kubectl get POD -l app.kubernetes.io/name=memsql-cluster,app.kubernetes.io/instance=${CLUSTER_NAME} -o custom-columns=NAME:.metadata.name --no-headers)"
    echo $(echo -n $PODS | sed -e's/\s\+/,/g');
}

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

export -f getPods
export -f getCluster_collection_script
export -f getAWS_command
