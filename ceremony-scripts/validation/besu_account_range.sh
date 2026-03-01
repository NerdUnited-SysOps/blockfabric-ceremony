#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Environment config file"
	echo "  -h : This help message"
}

while getopts he: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${RPC_PORT}" ]] && echo "${0}:${LINENO} .env is missing RPC_PORT variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${NODE_USER}" ]] && echo "${0}:${LINENO} .env is missing NODE_USER variable" && exit 1

# Get first RPC node IP from inventory
RPC_IP=$(ansible --list-hosts -i ${INVENTORY_PATH} rpc | sed '/:/d ; s/ //g' | head -1)

if [[ -z "${RPC_IP}" ]]; then
    # Fallback to first validator
    RPC_IP=$(ansible --list-hosts -i ${INVENTORY_PATH} validator | sed '/:/d ; s/ //g' | head -1)
fi

[[ -z "${RPC_IP}" ]] && echo "No hosts found in inventory" && exit 1

# Resolve actual SSH target IP from ansible inventory (hostname may point to TLS proxy, not the node)
SSH_TARGET=$(ansible-inventory -i ${INVENTORY_PATH} --host "${RPC_IP}" 2>/dev/null | jq -r '.ansible_host // empty')
[[ -z "${SSH_TARGET}" ]] && SSH_TARGET="${RPC_IP}"

# Read genesis.json from RPC node (debug_accountRange doesn't work with Besu BONSAI storage)
genesis_json=$(ssh -o StrictHostKeyChecking=no -i "${AWS_NODES_SSH_KEY_PATH}" "${NODE_USER}@${SSH_TARGET}" \
    "sudo cat /etc/besu/genesis.json" 2>/dev/null)

if [[ -z "${genesis_json}" ]]; then
    echo "Error: Could not read genesis.json from ${RPC_IP}"
    exit 1
fi

alloc_addresses=($(echo "${genesis_json}" | jq -r '.alloc | keys[]'))

if [[ ${#alloc_addresses[@]} -eq 0 ]]; then
    echo "Error: No alloc addresses found in genesis.json"
    exit 1
fi

hex_to_dec() {
    local hex=$1
    hex=${hex#0x}
    python3 -c "print(int('${hex}', 16))"
}

# Header
printf "\n%-44s %-10s %-14s %s\n" "ADDRESS" "TYPE" "LABEL" "BALANCE (wei)"
printf "%s\n" "$(printf '%.0s-' {1..90})"

total_balance=0
contract_count=0
eoa_count=0
account_count=0

for addr in "${alloc_addresses[@]}"; do
    addr_lower=$(echo "${addr}" | tr '[:upper:]' '[:lower:]')

    # Get balance via RPC
    balance_hex=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"${addr_lower}\", \"latest\"],\"id\":1}" \
        "http://${RPC_IP}:${RPC_PORT}" | jq -r '.result')
    balance_dec=$(hex_to_dec "${balance_hex}")

    # Get code to classify contract vs EOA
    code=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"${addr_lower}\", \"latest\"],\"id\":1}" \
        "http://${RPC_IP}:${RPC_PORT}" | jq -r '.result')

    if [[ "${code}" == "0x" ]] || [[ "${code}" == "0x0" ]] || [[ -z "${code}" ]]; then
        addr_type="EOA"
        eoa_count=$((eoa_count + 1))
    else
        addr_type="Contract"
        contract_count=$((contract_count + 1))
    fi

    # Get genesis comment/label if present
    label=$(echo "${genesis_json}" | jq -r --arg a "${addr}" '.alloc[$a].comment // empty')

    total_balance=$(python3 -c "print(${total_balance} + ${balance_dec})")
    account_count=$((account_count + 1))

    printf "%-44s %-10s %-14s %s\n" "${addr_lower}" "${addr_type}" "${label}" "${balance_dec}"
done

# Summary
printf "\n%s\n" "$(printf '%.0s-' {1..90})"
printf "Total Accounts: %d  (Contracts: %d, EOAs: %d)\n" ${account_count} ${contract_count} ${eoa_count}
printf "Total Balance:  %s wei\n" "${total_balance}"
