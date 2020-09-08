export MAXIMUM_MEMORY=2048
export ROOT_PASSWORD=testing
export RELEASE_ID=latest
export ENABLE_SERVICE_USER=1

if [[ -z "${LICENSE_KEY}" ]]; then
    echo "Must specify env variable LICENSE_KEY"
    exit 1
fi
if [[ -z "${IMAGE}" ]]; then
    echo "Must specify env variable IMAGE"
    exit 1
fi

retry() {
    while true; do
        "${@}" && break || sleep 0.2
    done
}

create-node() {
    local name=${1}
    docker create \
        --name ${name} \
        -v ${name}:/var/lib/memsql \
        -e RELEASE_ID=${RELEASE_ID} \
        -e MAXIMUM_MEMORY=${MAXIMUM_MEMORY} \
        -e ROOT_PASSWORD=${ROOT_PASSWORD} \
        -e ENABLE_SERVICE_USER=${ENABLE_SERVICE_USER} \
        -e PRE_START_SCRIPT=/test-assets/pre-start \
        ${IMAGE}
    docker cp "${DIR}/assets" "${name}":/test-assets
    docker start ${name}
}

create-node-ssl() {
    local name=${1}
    docker create \
        --name ${name} \
        -v ${name}:/var/lib/memsql \
        -e ENABLE_SSL=1 \
        -e RELEASE_ID=${RELEASE_ID} \
        -e MAXIMUM_MEMORY=${MAXIMUM_MEMORY} \
        -e ENABLE_SERVICE_USER=${ENABLE_SERVICE_USER} \
        -e ROOT_PASSWORD=${ROOT_PASSWORD} \
        ${IMAGE}
    docker cp "${DIR}/certs" "${name}":/etc/memsql/ssl
    docker start ${name}
}

wait-start() {
    local name=${1}
    local iterations=0
    local max_iterations=60
    echo "waiting for node ${name} to start"
    while true; do
        sleep 0.5
        ((++iterations))

        local CONNECTABLE=$(memsqlctl ${name} describe-node --property IsConnectable || echo false)
        local RECOVERY=$(memsqlctl ${name} describe-node --property RecoveryState || echo Offline)
        if [[ ${CONNECTABLE} == "true" && ${RECOVERY} == "Online" ]]; then
            echo "node ${name}: started"
            break
        fi

        if [[ ${iterations} -ge ${max_iterations} ]]; then
            echo "node ${name} failed to start after 30 seconds"
            memsqlctl ${name} list-nodes
            memsqlctl ${name} describe-node
            exit 1
        fi
    done
}

restart-containers() {
    echo "restarting ${@}"
    docker restart "${@}"
    for name in "${@}"; do
        wait-start ${name}
    done
}

delete-containers() {
    docker rm -f "${@}"
}

run() {
    local name=${1}
    shift
    docker exec ${name} "${@}"
}

memsqlctl() {
    local name=${1}
    shift
    run ${name} memsqlctl -y "${@}"
}

query() {
    local name=${1}
    shift
    run ${name} memsqlctl query --json -e "${1}"
}

query-ssl() {
    local name=${1}
    shift
    run ${name} memsqlctl query --json -e "${1}" --ssl-ca /etc/memsql/ssl/ca-cert.pem
}

docker-ip() {
    docker inspect -f '{{ .NetworkSettings.IPAddress }}' ${1}
}

bootstrap() {
    local name=${1}
    echo "bootstrapping ${name}"
    memsqlctl ${name} set-license --license "${LICENSE_KEY}"
    memsqlctl ${name} bootstrap-aggregator --host $(docker-ip ${name})
}

add-leaf() {
    local master=${1}
    local leaf=${2}
    echo "adding leaf ${leaf} to ${master}"
    memsqlctl ${master} add-leaf --host $(docker-ip ${leaf}) --password ${ROOT_PASSWORD}
}

remove-leaf() {
    local master=${1}
    local leaf=${2}
    echo "removing leaf ${leaf} from ${master}"
    memsqlctl ${master} remove-leaf --host $(docker-ip ${leaf})
}

assert-memsqld-running() {
    local name=${1}
    echo "${name}: verifying memsqld_safe and memsqld are running"
    run ${name} ps aux | grep memsqld_safe
    run ${name} ps aux | grep memsqld
    echo "${name}: memsqld_safe and memsqld are running"
}

memsql-init-data() {
    local name=${1}
    echo "initializing test data"
    query ${name} "create database test" >/dev/null
    query ${name} "create table test.foo (id int)" >/dev/null
    query ${name} "insert into test.foo (id) values (1)" >/dev/null
    query ${name} "insert into test.foo select * from test.foo" >/dev/null
    query ${name} "insert into test.foo select * from test.foo" >/dev/null
    query ${name} "insert into test.foo select * from test.foo" >/dev/null
    query ${name} "insert into test.foo select * from test.foo" >/dev/null
}

memsql-verify-data() {
    local name=${1}
    local count=$(
        query ${name} "select count(*) as c from test.foo" \
        | jq -r '.rows[0].c'
    )
    local expected_count="16"
    if [[ "${count}" != "${expected_count}" ]]; then
        echo "Amount of data in MemSQL differs from what is expected"
        echo ${count}
        echo ${expected_count}
        exit 1
    fi
}
