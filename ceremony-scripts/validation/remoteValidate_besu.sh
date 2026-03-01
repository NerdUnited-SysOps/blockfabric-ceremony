#!/usr/bin/env zsh

set -e

RPC_URL=$1

if [[ -z "${RPC_URL}" ]]; then
    echo "Usage: remoteValidate_besu.sh <rpc_url>"
    echo "  e.g. remoteValidate_besu.sh http://<rpc-host>:8669"
    exit 1
fi

rpc_call() {
    local method=$1
    local params=${2:-[]}

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" \
        "${RPC_URL}"
}

hex_to_dec() {
    local hex=$1
    hex=${hex#0x}
    python3 -c "print(int('${hex}', 16))"
}

strip_hex_prefix_and_zeros() {
    local val=$1
    val=${val#0x}
    val=$(echo "$val" | sed "s/^0*//")
    [[ -z "$val" ]] && val="0"
    echo "$val"
}

repeat_char() {
    local c=$1
    local len=$2
    printf "%${len}s" | tr ' ' "${c}"
}

tab() {
    local first=$1
    local second=$2
    local max_length=${3:-66}
    local space=$((max_length - ${#first} - ${#second}))
    [[ $space -lt 1 ]] && space=1
    printf "%s%${space}s%s" "$first" "" "$second"
}

# Contract addresses (same as remoteValidate.js)
LOCKUP_ADDRESS="0x47e9fbef8c83a1714f1951f142132e6e90f5fa5d"
DISTRIBUTION_ADDRESS="0x8be503bcded90ed42eff31f56199399b2b0154ca"

# Storage slot keys (full 32-byte)
SLOT_0="0x0000000000000000000000000000000000000000000000000000000000000000"
SLOT_1="0x0000000000000000000000000000000000000000000000000000000000000001"
SLOT_2="0x0000000000000000000000000000000000000000000000000000000000000002"
SLOT_4="0x0000000000000000000000000000000000000000000000000000000000000004"
SLOT_5="0x0000000000000000000000000000000000000000000000000000000000000005"

ROW_LENGTH=66

# Get all accounts from genesis.json (debug_accountRange doesn't work with Besu BONSAI storage)
RPC_HOST=$(echo "${RPC_URL}" | sed 's|https\?://||;s|:.*||')
GENESIS_SSH_KEY=${AWS_NODES_SSH_KEY_PATH:-${HOME}/blockfabric-ceremony/id_rsa_nodes}
GENESIS_SSH_USER=${NODE_USER:-besu}

# Resolve actual SSH target IP from ansible inventory (hostname may point to TLS proxy, not the node)
SSH_TARGET="${RPC_HOST}"
if [[ -n "${INVENTORY_PATH}" ]]; then
    resolved=$(ansible-inventory -i "${INVENTORY_PATH}" --host "${RPC_HOST}" 2>/dev/null | jq -r '.ansible_host // empty')
    [[ -n "${resolved}" ]] && SSH_TARGET="${resolved}"
fi

genesis_json=$(ssh -o StrictHostKeyChecking=no -i "${GENESIS_SSH_KEY}" "${GENESIS_SSH_USER}@${SSH_TARGET}" \
    "sudo cat /etc/besu/genesis.json" 2>/dev/null)

if [[ -z "${genesis_json}" ]]; then
    echo "Error: Could not read genesis.json from ${SSH_TARGET}"
    exit 1
fi

all_addresses=($(echo "${genesis_json}" | jq -r '.alloc | keys[]' | tr '[:upper:]' '[:lower:]'))

get_distribution_issuer() {
    # Read issuer address directly from distribution contract storage slot 1
    local raw=$(rpc_call "eth_getStorageAt" "[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_1}\", \"latest\"]" | jq -r '.result')
    raw=${raw#0x}
    echo "0x${raw: -40}"
}

distribution_issuer_address=$(get_distribution_issuer)

# Get balances
lockup_balance=$(rpc_call "eth_getBalance" "[\"${LOCKUP_ADDRESS}\", \"latest\"]" | jq -r '.result')
lockup_balance_dec=$(hex_to_dec "${lockup_balance}")

distribution_balance=$(rpc_call "eth_getBalance" "[\"${DISTRIBUTION_ADDRESS}\", \"latest\"]" | jq -r '.result')
distribution_balance_dec=$(hex_to_dec "${distribution_balance}")

issuer_balance=$(rpc_call "eth_getBalance" "[\"${distribution_issuer_address}\", \"latest\"]" | jq -r '.result')
issuer_balance_dec=$(hex_to_dec "${issuer_balance}")

# Get lockup storage
lockup_issuer_raw=$(rpc_call "eth_getStorageAt" "[\"${LOCKUP_ADDRESS}\", \"${SLOT_2}\", \"latest\"]" | jq -r '.result')
lockup_daily_unlock_raw=$(rpc_call "eth_getStorageAt" "[\"${LOCKUP_ADDRESS}\", \"${SLOT_4}\", \"latest\"]" | jq -r '.result')
lockup_timestamp_raw=$(rpc_call "eth_getStorageAt" "[\"${LOCKUP_ADDRESS}\", \"${SLOT_5}\", \"latest\"]" | jq -r '.result')

lockup_daily_unlock_dec=$(hex_to_dec "${lockup_daily_unlock_raw}")
lockup_timestamp_dec=$(hex_to_dec "${lockup_timestamp_raw}")

# Get distribution storage
distribution_owner_raw=$(rpc_call "eth_getStorageAt" "[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_0}\", \"latest\"]" | jq -r '.result')
distribution_issuer_raw=$(rpc_call "eth_getStorageAt" "[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_1}\", \"latest\"]" | jq -r '.result')
distribution_lockup_raw=$(rpc_call "eth_getStorageAt" "[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_2}\", \"latest\"]" | jq -r '.result')

# Calculate total chain balance (using bc for large numbers)
total_balance=0
for addr in "${all_addresses[@]}"; do
    bal=$(rpc_call "eth_getBalance" "[\"${addr}\", \"latest\"]" | jq -r '.result')
    bal_dec=$(hex_to_dec "${bal}")
    total_balance=$(python3 -c "print(${total_balance} + ${bal_dec})")
done

# Calculate days since unlock and current unlocked
now_seconds=$(date +%s)
days_since_unlock=$(( (now_seconds - lockup_timestamp_dec) / 60 / 60 / 24 ))
current_unlocked=$(( days_since_unlock * lockup_daily_unlock_dec ))
[[ $current_unlocked -lt 0 ]] && current_unlocked=0

# Get chain metadata
chain_id_hex=$(rpc_call "eth_chainId" | jq -r '.result')
chain_id_dec=$(hex_to_dec "${chain_id_hex}")
net_version=$(rpc_call "net_version" | jq -r '.result')

# Distribution started date
distribution_started=$(date -d @${lockup_timestamp_dec} 2>/dev/null || date -r ${lockup_timestamp_dec} 2>/dev/null)

# Contract routing comparisons (strip 0x prefix and leading zeros, matching .substring(2) from JS)
lockup_issuer_stripped=$(strip_hex_prefix_and_zeros "${lockup_issuer_raw}")
distribution_contract_stripped=$(strip_hex_prefix_and_zeros "${DISTRIBUTION_ADDRESS}")
lockup_issuer_matches_distribution=$([[ "${lockup_issuer_stripped}" == "${distribution_contract_stripped}" ]] && echo "true" || echo "false")

distribution_lockup_stripped=$(strip_hex_prefix_and_zeros "${distribution_lockup_raw}")
lockup_contract_stripped=$(strip_hex_prefix_and_zeros "${LOCKUP_ADDRESS}")
distribution_lockup_matches_lockup=$([[ "${distribution_lockup_stripped}" == "${lockup_contract_stripped}" ]] && echo "true" || echo "false")

distribution_issuer_storage_stripped=$(strip_hex_prefix_and_zeros "${distribution_issuer_raw}")
distribution_issuer_address_stripped=$(strip_hex_prefix_and_zeros "${distribution_issuer_address}")
distribution_issuer_matches=$([[ "${distribution_issuer_storage_stripped}" == "${distribution_issuer_address_stripped}" ]] && echo "true" || echo "false")

# Print output (matching remoteValidate.js format exactly)
echo ""
echo "$(repeat_char '-' ${ROW_LENGTH})"
echo " Balances"
echo "$(repeat_char '-' ${ROW_LENGTH})"

echo "$(tab " Lockup Daily Unlock" "${lockup_daily_unlock_dec}" ${ROW_LENGTH})"
echo "$(tab " Lockup Balance" "${lockup_balance_dec}" ${ROW_LENGTH})"
echo "$(tab " Current Unlocked" "${current_unlocked}" ${ROW_LENGTH})"
echo "$(tab " Distribution Contract" "${distribution_balance_dec}" ${ROW_LENGTH})"
echo "$(tab " Distribution Issuer" "${issuer_balance_dec}" ${ROW_LENGTH})"
echo ""
echo "$(tab " Total Chain Balance" "${total_balance}" ${ROW_LENGTH})"

echo ""
echo "$(repeat_char '-' ${ROW_LENGTH})"
echo " Addresses"
echo "$(repeat_char '-' ${ROW_LENGTH})"

echo "$(tab " Lockup Contract" "${LOCKUP_ADDRESS}" ${ROW_LENGTH})"
echo "$(tab " Distribution Contract" "${DISTRIBUTION_ADDRESS}" ${ROW_LENGTH})"
echo "$(tab " Distribution Issuer" "${distribution_issuer_address}" ${ROW_LENGTH})"

echo ""
echo "$(repeat_char '-' ${ROW_LENGTH})"
echo " General Metrics"
echo "$(repeat_char '-' ${ROW_LENGTH})"

echo "$(tab " Distribution Started" "${distribution_started}" ${ROW_LENGTH})"
echo "$(tab " Days Since Unlock" "${days_since_unlock}" ${ROW_LENGTH})"
echo "$(tab " Network Version" "${net_version}" ${ROW_LENGTH})"
echo "$(tab " Chain ID" "${chain_id_dec}" ${ROW_LENGTH})"

echo ""
echo "$(repeat_char '-' ${ROW_LENGTH})"
echo " Contract Routing"
echo "$(repeat_char '-' ${ROW_LENGTH})"

echo "$(tab " Lockup Issuer Address == Distribution Contract" "${lockup_issuer_matches_distribution}" ${ROW_LENGTH})"
echo "$(tab " Distribution Lockup Address == Lockup Contract" "${distribution_lockup_matches_lockup}" ${ROW_LENGTH})"
echo "$(tab " DistributionIssuer == DistributionIssuerAddress" "${distribution_issuer_matches}" ${ROW_LENGTH})"
echo ""

echo "Validation Complete"
