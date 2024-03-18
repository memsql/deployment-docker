INIT_FLAG=/.initialized
CHANNELS=(production dev cloud)

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

isVersionGE()
{
    local arg_major=${1}
    local arg_minor=${2}

    local version=$(memsqlctl version | sed -n 's/^Version: \(.*\)$/\1/p')
    local versionParts=($(echo ${version//./ }))
    local major=${versionParts[0]}
    local minor=${versionParts[1]}
    local patch=${versionParts[2]}

    if [[ "${major}" -ne ${arg_major} ]]; then
        if [[ "${major}" -gt ${arg_major} ]]; then
            return 0
        else
            return 1
        fi
    fi

    if [[ "${minor}" -ne ${arg_minor} ]]; then
        if [[ "${minor}" -gt ${arg_minor} ]]; then
            return 0
        else
            return 1
        fi
    fi

    return 0
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

setJava11Path() {
    if isVersionGE 8 5; then
        memsqlctl -y update-config --key java_pipelines_java11_path --value $(which java)
    fi
}

setJava21Path() {
    if isVersionGE 8 7; then
        # Look up the installation path in the alternatives list.  If we don't
        # find one, do nothing.
        local java21Path=$(update-alternatives --list | grep '^jre_21\b' | cut -f 3 2>/dev/null)
        if [ -n "${java21Path}" ] ; then
            memsqlctl -y update-config --key fts2_java_path --value "${java21Path}/bin/java"
            memsqlctl -y update-config --key fts2_java_home --value "${java21Path}"
        fi
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
    local pid=${1}
    while true; do
        local CONNECTABLE=$(memsqlctl describe-node --property IsConnectable || echo false)
        if [[ ${CONNECTABLE} == "true" ]]; then
            break
        fi

        if kill -0 $pid; then
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

    # as a sanity check, make sure there isn't an existing process running memsqldSafePath
    # use || true to not fail due to `set -e` if it does not exist
    existing_memsql_pid=$(pgrep -f ${memsqldSafePath}) || true
    if [[ "$existing_memsql_pid" != "" ]]; then
        log "Error, there is an existing memsql process running '$memsqldSafePath' with PID $existing_memsql_pid"
        exit 1
    fi

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