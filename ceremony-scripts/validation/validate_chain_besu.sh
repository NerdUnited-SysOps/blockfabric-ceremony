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
        h) usage; exit 0 ;;
        i) INVENTORY_PATH=${OPTARG} ;;
        p) RPC_PORT=${OPTARG} ;;
        r) RPC_PATH=${OPTARG} ;;
        v) VALIDATION_SCRIPT=${OPTARG} ;;
    esac
done

title() {
    echo -e "------------------------------------------------------------------"
    echo -e "$1"
    printf "------------------------------------------------------------------\n\n"
}

get_ips() {
    group=${1:-rpc}
    ansible-inventory -i ${INVENTORY_PATH} --list 2>/dev/null \
        | jq -r --arg g "$group" '
            .[$g].hosts[] as $h |
            select(._meta.hostvars[$h].skip_validation != "true") |
            ._meta.hostvars[$h].ansible_host // empty
        ' | tr "\n" " " ; echo
}

ssh_rpc_call() {
    local ip=$1
    local method=$2
    local params=${3:-[]}
    local scheme=${4:-http}

    LC_ALL= ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
        -i ${AWS_NODES_SSH_KEY_PATH} ${NODE_USER}@${ip} \
        "curl -sk --max-time 3 -X POST -H 'Content-Type: application/json' \
        -d '{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}' \
        ${scheme}://localhost:${RPC_PORT}"
}

verify_each() {
    local HOST=$1
    local SCHEME=${2:-http}

    # Batch all 3 RPC calls in a single SSH session to avoid connection storms
    # JSON is parsed locally (jq may not be installed on target nodes)
    local raw=$(LC_ALL= ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -i ${AWS_NODES_SSH_KEY_PATH} ${NODE_USER}@${HOST} "
        curl -sk --max-time 3 -X POST -H 'Content-Type: application/json' \
            -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_gasPrice\",\"params\":[],\"id\":1}' \
            ${SCHEME}://localhost:${RPC_PORT} 2>/dev/null
        echo ''
        curl -sk --max-time 3 -X POST -H 'Content-Type: application/json' \
            -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":2}' \
            ${SCHEME}://localhost:${RPC_PORT} 2>/dev/null
        echo ''
        curl -sk --max-time 3 -X POST -H 'Content-Type: application/json' \
            -d '{\"jsonrpc\":\"2.0\",\"method\":\"net_peerCount\",\"params\":[],\"id\":3}' \
            ${SCHEME}://localhost:${RPC_PORT} 2>/dev/null
    " 2>/dev/null)

    local gas_hex=$(echo $raw | sed -n '1p' | jq -r '.result')
    local block_hex=$(echo $raw | sed -n '2p' | jq -r '.result')
    local peers_hex=$(echo $raw | sed -n '3p' | jq -r '.result')

    local gas=$((${gas_hex}))
    local block=$((${block_hex}))
    local peers=$((${peers_hex}))

    printf " IP: ${HOST}\tGas: ${gas} Block: ${block} Peers: ${peers}\n"
}

verify_blockchain() {
    local node_ip=$(get_ips validator | awk '{print $1}')

    RPC_SSH_HOST=${node_ip} \
    RPC_SSH_KEY=${AWS_NODES_SSH_KEY_PATH} \
    RPC_SSH_USER=${NODE_USER} \
    RPC_PORT=${RPC_PORT} \
    ${VALIDATION_SCRIPT}
}

RPC_IP_LIST=$(get_ips rpc)
VALIDATOR_IP_LIST=$(get_ips validator)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Start ALL background jobs up front ---

typeset -a tls_pids val_pids rpc_pids
typeset -a tls_ips val_ips rpc_ips

# TLS
for IP in $(echo $RPC_IP_LIST); do
    (
        result="Checking TLS for ${IP}\t"
        if curl --max-time 3 -k https://${IP}:${RPC_PORT}/ &>/dev/null; then
            result+="${GREEN}Success${NC}"
        else
            result+="${RED}Failure${NC}"
        fi
        printf "$result" > /tmp/_validate_tls_${IP}
    ) &
    tls_pids+=($!)
    tls_ips+=($IP)
done

# Validators
for ip in $(echo $VALIDATOR_IP_LIST); do
    ( verify_each $ip > /tmp/_validate_val_${ip} ) &
    val_pids+=($!)
    val_ips+=($ip)
done

# RPCs
for ip in $(echo $RPC_IP_LIST); do
    ( verify_each $ip https > /tmp/_validate_rpc_${ip} ) &
    rpc_pids+=($!)
    rpc_ips+=($ip)
done

# Chain validation
( verify_blockchain > /tmp/_validate_chain 2>&1 ) &
chain_pid=$!

# --- Display each section, streaming as results arrive ---

title "HTTPS Status"
for i in {1..${#tls_pids}}; do
    wait ${tls_pids[$i]} 2>/dev/null
    printf "$(cat /tmp/_validate_tls_${tls_ips[$i]} 2>/dev/null)\n"
done

title "Status of validator"
for i in {1..${#val_pids}}; do
    wait ${val_pids[$i]} 2>/dev/null
    cat /tmp/_validate_val_${val_ips[$i]} 2>/dev/null
done

title "Status of rpc"
for i in {1..${#rpc_pids}}; do
    wait ${rpc_pids[$i]} 2>/dev/null
    cat /tmp/_validate_rpc_${rpc_ips[$i]} 2>/dev/null
done

wait $chain_pid 2>/dev/null
echo ""
cat /tmp/_validate_chain 2>/dev/null

# cleanup
rm -f /tmp/_validate_tls_* /tmp/_validate_val_* /tmp/_validate_rpc_* /tmp/_validate_chain
