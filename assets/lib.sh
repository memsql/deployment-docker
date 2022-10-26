INIT_FLAG=/.initialized
CHANNELS=(production dev)

log() { (>&2 echo "${@}") }

once() {
    local lock="${1}"
    shift
    if [ ! -f "${lock}" ]; then
        "${@}"
        touch "${lock}"
    fi
}

getReleaseInfo() {
    local channel="${1}"
    local releaseid="${2}"
    local url="https://release.memsql.com/${channel}/index/memsqlserver/${releaseid}.json"
    log "Attempting to download: ${url}"
    curl -sf "${url}" || echo ""
}

installRelease() {
    local releaseid="${1}"
    log "Installing SingleStore DB release ${releaseid}"
    for channel in ${CHANNELS[@]}; do
        local info=$(getReleaseInfo ${channel} ${releaseid})
        if [ -n "${info}" ]; then
            local rpmpath=$(echo "${info}" | jq -r '.packages."memsql-server-rpm".Path')
            local rpmurl="https://release.memsql.com/${rpmpath}"
            log "Success, installing RPM: ${rpmurl}"
            rpm -i "${rpmurl}"
            return
        fi
    done

    log "Failed to download release ${RELEASE_ID} from any channel"
    return 1
}

createNode() {
    log "Initializing SingleStore DB node"
    memsqlctl -y create-node --no-start --base-install-dir /var/lib/memsql/instance
    memsqlctl -y update-config --key minimum_core_count --value 0
    memsqlctl -y update-config --key minimum_memory_mb --value 0
    memsqlctl -y update-config --key skip_host_cache --value on
}

setMaximumMemory() {
    local memory="${1}"
    if [ -n "${memory}" ]; then
        log "Setting maximum_memory to ${memory}"
        memsqlctl -y update-config --key maximum_memory --value "${memory}"
    fi
}

checkSSL() {
    local code=0
    if [ ! -r /etc/memsql/ssl/server-cert.pem ]; then
        log "Cannot read /etc/memsql/ssl/server-cert.pem"
        code=1
    fi
    if  [ ! -r /etc/memsql/ssl/server-key.pem ]; then
        log "Cannot read /etc/memsql/ssl/server-key.pem"
        code=1
    fi
    return $code
}

enableSSL() {
    log "Enabling SSL"
    checkSSL || return 1
    memsqlctl -y update-config --key ssl_cert --value /etc/memsql/ssl/server-cert.pem
    memsqlctl -y update-config --key ssl_key  --value /etc/memsql/ssl/server-key.pem
}

waitStart() {
    while true; do
        local CONNECTABLE=$(memsqlctl describe-node --property IsConnectable || echo false)
        if [[ ${CONNECTABLE} == "true" ]]; then
            break
        fi

        if kill -0 $PID; then
            # memsqld still running, retry
            sleep 0.2
        else
            # memsdl is gone
            log "memsqld exited"
            exit 1
        fi
        
    done
}

startSingleStore() {
    local installDir=$(dirname $(readlink -f /usr/bin/memsqlctl))
    local memsqldPath=${installDir}/memsqld
    local memsqldSafePath=${installDir}/memsqld_safe

    env -u ROOT_PASSWORD ${memsqldSafePath} \
        --auto-restart disable \
        --defaults-file $(memsqlctl describe-node --property MemsqlConfig) \
        --memsqld ${memsqldPath} \
        --user ${UID} &
}

updateRootPassword() {
    local password="${1}"
    log "Ensuring the root password is setup"

    # due to a bug in sync_permissions we need to manually grant first and then
    # fix rather than just using change-root-password directly
    # https://memsql.atlassian.net/browse/DB-35989
    # if we fail because of an upgrade, catch error and log
    # if error that is not caused by an upgrade occurs, log and raise error
    local ret=$(memsqlctl query -e "GRANT ALL ON *.* TO root@'%' IDENTIFIED BY '${password}'" 2>&1)
    if [[ ${ret} == *"Error 1706"* ]]; then
        log "cluster is currently upgrading, root password should already be set,"
    elif [[ ${ret} == *"Error"* ]]; then
        log "error setting root password: ${ret}"
        exit 1
    fi
    # if we fail to connect then the password likely changed
    if ! memsqlctl query -e "SELECT 1"; then
        memsqlctl -y change-root-password --password "${password}"
    fi
}
