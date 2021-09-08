if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "MUST BE SOURCED!"; exit 1; fi

# Define functions to control how reports are run on the cluster

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

export -f getCluster_collection_script
export -f getAWS_command
