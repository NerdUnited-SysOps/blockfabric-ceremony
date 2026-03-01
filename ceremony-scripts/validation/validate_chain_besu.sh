#!/usr/bin/env zsh

set -e

usage() {
  echo "Options"
  echo "  -h : This help message"
  echo "  -i : Path to inventory file"
  echo "  -p : RPC Port"
  echo "  -r : RPC hostname (for TLS checks)"
  echo "  -v : Path to remoteValidate_besu.sh script"
}

while getopts i:p:r:v: option; do
    case "${option}" in
        h)
            usage
            exit 0
            ;;
        i)
            INVENTORY_PATH=${OPTARG}
            ;;
        p)
            RPC_PORT=${OPTARG}
            ;;
        r)
            RPC_PATH=${OPTARG}
            ;;
        v)
            VALIDATION_SCRIPT=${OPTARG}
            ;;
    esac
done

title() {
    title=$1

    echo -e "------------------------------------------------------------------";
    echo -e "${title}";
    printf "------------------------------------------------------------------\n\n";
}

get_ips() {
    group=${1:-rpc}
    ansible \
			--list-hosts \
			-i ${INVENTORY_PATH} \
			${group} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

curl_check() {
    ip=$1

    curl \
        --max-time 5.5 \
        https://${RPC_PATH}:${RPC_PORT}/ --connect-to "${RPC_PATH}:${RPC_PORT}:${ip}:${RPC_PORT}" &>> ${LOG_FILE}
}

check_https() {
    IP_LIST=$1

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'

    title "HTTPS Status"

		for IP in $(echo $IP_LIST | tr ' ' ' '); do
        result="Checking TLS for ${IP}\t"
        if curl_check ${IP}; then
            result+="${GREEN}Success${NC}"
        else
            result+="${RED}Failure${NC}"
        fi
        printf "$result\n"
    done
}

rpc_call() {
    local ip=$1
    local method=$2
    local params=${3:-[]}

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" \
        "http://${ip}:${RPC_PORT}"
}

verify_each() {
	local HOST=$1

	local gas_hex=$(rpc_call ${HOST} "eth_gasPrice" | jq -r '.result')
	local block_hex=$(rpc_call ${HOST} "eth_blockNumber" | jq -r '.result')
	local peers_hex=$(rpc_call ${HOST} "net_peerCount" | jq -r '.result')

	local gas=$((${gas_hex}))
	local block=$((${block_hex}))
	local peers=$((${peers_hex}))

	printf " IP: ${HOST}\tGas: ${gas} Block: ${block} Peers: ${peers}\n"
}

verify_group() {
    GROUP=$1

    title "Status of ${GROUP}"

    for ip in $(get_ips ${GROUP}); do
			verify_each $ip &
    done
    wait
}

verify_blockchain() {
    local rpc_ip=$(get_ips rpc | awk '{print $1}')
    if [[ -z "${rpc_ip}" ]]; then
        rpc_ip=$(get_ips validator | awk '{print $1}')
    fi

    ${VALIDATION_SCRIPT} "http://${rpc_ip}:${RPC_PORT}"
}

RPC_IP_LIST=$(get_ips rpc)

check_https "${RPC_IP_LIST}"
verify_group validator
verify_group rpc
verify_blockchain
