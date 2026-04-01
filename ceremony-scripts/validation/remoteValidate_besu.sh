#!/usr/bin/env zsh

set -e

if [[ -z "${RPC_SSH_HOST}" || -z "${RPC_SSH_KEY}" || -z "${RPC_SSH_USER}" || -z "${RPC_PORT}" ]]; then
    echo "Usage: RPC_SSH_HOST=<ip> RPC_SSH_KEY=<key> RPC_SSH_USER=<user> RPC_PORT=<port> remoteValidate_besu.sh"
    echo "  Environment variables must be set by the caller."
    exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o LogLevel=ERROR -i "${RPC_SSH_KEY}")

# Run a single RPC call via SSH (used for Phase 1 only)
rpc_call() {
    local method=$1
    local params=${2:-[]}
    LC_ALL= ssh "${SSH_OPTS[@]}" "${RPC_SSH_USER}@${RPC_SSH_HOST}" \
        "curl -s --max-time 3 -X POST -H 'Content-Type: application/json' \
        -d '{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}' \
        http://localhost:${RPC_PORT}"
}

# Run multiple RPC calls in a single SSH session, output one JSON result per line
rpc_batch() {
    # Build a remote script that runs all curls sequentially
    local remote_script=""
    for call in "$@"; do
        local method="${call%%|*}"
        local params="${call#*|}"
        [[ "${params}" == "${method}" ]] && params="[]"
        remote_script+="curl -s --max-time 3 -X POST -H 'Content-Type: application/json' "
        remote_script+="-d '{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}' "
        remote_script+="http://localhost:${RPC_PORT}; echo;"$'\n'
    done

    LC_ALL= ssh "${SSH_OPTS[@]}" "${RPC_SSH_USER}@${RPC_SSH_HOST}" "${remote_script}"
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

# Convert wei to token units (divide by 10^18) and format with commas
format_tokens() {
    python3 -c "
v = int('${1}')
t = v // 10**18
r = v % 10**18
if r == 0:
    print(f'{t:,}')
else:
    frac = f'{r:018d}'.rstrip('0')
    print(f'{t:,}.{frac}')
"
}

# Contract addresses
LOCKUP_ADDRESS="0x47e9fbef8c83a1714f1951f142132e6e90f5fa5d"
DISTRIBUTION_ADDRESS="0x8be503bcded90ed42eff31f56199399b2b0154ca"

# Storage slot keys
SLOT_0="0x0000000000000000000000000000000000000000000000000000000000000000"
SLOT_1="0x0000000000000000000000000000000000000000000000000000000000000001"
SLOT_2="0x0000000000000000000000000000000000000000000000000000000000000002"
SLOT_3="0x0000000000000000000000000000000000000000000000000000000000000003"

ROW_LENGTH=66

# Read genesis.json
genesis_json=$(ssh "${SSH_OPTS[@]}" "${RPC_SSH_USER}@${RPC_SSH_HOST}" \
    "sudo cat /etc/besu/genesis.json" 2>/dev/null)

if [[ -z "${genesis_json}" ]]; then
    echo "Error: Could not read genesis.json from ${RPC_SSH_HOST}"
    exit 1
fi

all_addresses=($(echo "${genesis_json}" | jq -r '.alloc | keys[]' | tr '[:upper:]' '[:lower:]'))

# Phase 1: Get distribution issuer address (needed to build Phase 2 batch)
get_distribution_issuer() {
    local raw=$(rpc_call "eth_getStorageAt" "[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_1}\", \"latest\"]" | jq -r '.result')
    raw=${raw#0x}
    echo "0x${raw: -40}"
}

distribution_issuer_address=$(get_distribution_issuer)

# Phase 2: Batch all independent RPC calls in ONE SSH session
# Order must match the read-back below
batch_calls=(
    "eth_getBalance|[\"${LOCKUP_ADDRESS}\", \"latest\"]"
    "eth_getBalance|[\"${DISTRIBUTION_ADDRESS}\", \"latest\"]"
    "eth_getBalance|[\"${distribution_issuer_address}\", \"latest\"]"
    "eth_getStorageAt|[\"${LOCKUP_ADDRESS}\", \"${SLOT_0}\", \"latest\"]"
    "eth_getStorageAt|[\"${LOCKUP_ADDRESS}\", \"${SLOT_2}\", \"latest\"]"
    "eth_getStorageAt|[\"${LOCKUP_ADDRESS}\", \"${SLOT_3}\", \"latest\"]"
    "eth_getStorageAt|[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_0}\", \"latest\"]"
    "eth_getStorageAt|[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_1}\", \"latest\"]"
    "eth_getStorageAt|[\"${DISTRIBUTION_ADDRESS}\", \"${SLOT_2}\", \"latest\"]"
    "eth_chainId|[]"
    "net_version|[]"
)

batch_results=("${(@f)$(rpc_batch "${batch_calls[@]}")}")

# Read results by line index (1-based in zsh)
lockup_balance=$(echo "${batch_results[1]}" | jq -r '.result')
lockup_balance_dec=$(hex_to_dec "${lockup_balance}")

distribution_balance=$(echo "${batch_results[2]}" | jq -r '.result')
distribution_balance_dec=$(hex_to_dec "${distribution_balance}")

issuer_balance=$(echo "${batch_results[3]}" | jq -r '.result')
issuer_balance_dec=$(hex_to_dec "${issuer_balance}")

lockup_issuer_raw=$(echo "${batch_results[4]}" | jq -r '.result')
lockup_daily_unlock_raw=$(echo "${batch_results[5]}" | jq -r '.result')
lockup_timestamp_raw=$(echo "${batch_results[6]}" | jq -r '.result')

lockup_daily_unlock_dec=$(hex_to_dec "${lockup_daily_unlock_raw}")
lockup_timestamp_dec=$(hex_to_dec "${lockup_timestamp_raw}")

distribution_owner_raw=$(echo "${batch_results[7]}" | jq -r '.result')
distribution_issuer_raw=$(echo "${batch_results[8]}" | jq -r '.result')
distribution_lockup_raw=$(echo "${batch_results[9]}" | jq -r '.result')

chain_id_hex=$(echo "${batch_results[10]}" | jq -r '.result')
chain_id_dec=$(hex_to_dec "${chain_id_hex}")
net_version=$(echo "${batch_results[11]}" | jq -r '.result')

# Phase 3: Per-address balances in ONE SSH session
addr_calls=()
for addr in "${all_addresses[@]}"; do
    addr_calls+=("eth_getBalance|[\"${addr}\", \"latest\"]")
done

addr_results=("${(@f)$(rpc_batch "${addr_calls[@]}")}")

# Calculate total chain balance
total_balance=0
for i in {1..${#all_addresses}}; do
    bal=$(echo "${addr_results[$i]}" | jq -r '.result')
    bal_dec=$(hex_to_dec "${bal}")
    total_balance=$(python3 -c "print(${total_balance} + ${bal_dec})")
done

# Calculate days since unlock and current unlocked
now_seconds=$(date +%s)
days_since_unlock=$(( (now_seconds - lockup_timestamp_dec) / 60 / 60 / 24 ))
current_unlocked=$(python3 -c "print(max(0, ${days_since_unlock} * ${lockup_daily_unlock_dec}))")

# Distribution started date
distribution_started=$(date -d @${lockup_timestamp_dec} 2>/dev/null || date -r ${lockup_timestamp_dec} 2>/dev/null)

# Contract routing comparisons
lockup_issuer_stripped=$(strip_hex_prefix_and_zeros "${lockup_issuer_raw}")
distribution_contract_stripped=$(strip_hex_prefix_and_zeros "${DISTRIBUTION_ADDRESS}")
lockup_issuer_matches_distribution=$([[ "${lockup_issuer_stripped}" == "${distribution_contract_stripped}" ]] && echo "true" || echo "false")

distribution_lockup_stripped=$(strip_hex_prefix_and_zeros "${distribution_lockup_raw}")
lockup_contract_stripped=$(strip_hex_prefix_and_zeros "${LOCKUP_ADDRESS}")
distribution_lockup_matches_lockup=$([[ "${distribution_lockup_stripped}" == "${lockup_contract_stripped}" ]] && echo "true" || echo "false")

distribution_issuer_storage_stripped=$(strip_hex_prefix_and_zeros "${distribution_issuer_raw}")
distribution_issuer_address_stripped=$(strip_hex_prefix_and_zeros "${distribution_issuer_address}")
distribution_issuer_matches=$([[ "${distribution_issuer_storage_stripped}" == "${distribution_issuer_address_stripped}" ]] && echo "true" || echo "false")

# Print output
echo ""
echo "$(repeat_char '-' ${ROW_LENGTH})"
echo " Balances"
echo "$(repeat_char '-' ${ROW_LENGTH})"

echo "$(tab " Lockup Daily Unlock" "$(format_tokens ${lockup_daily_unlock_dec})" ${ROW_LENGTH})"
echo "$(tab " Lockup Balance" "$(format_tokens ${lockup_balance_dec})" ${ROW_LENGTH})"
echo "$(tab " Current Unlocked" "$(format_tokens ${current_unlocked})" ${ROW_LENGTH})"
echo "$(tab " Distribution Contract" "$(format_tokens ${distribution_balance_dec})" ${ROW_LENGTH})"
echo "$(tab " Distribution Issuer" "$(format_tokens ${issuer_balance_dec})" ${ROW_LENGTH})"
echo ""
echo "$(tab " Total Chain Balance" "$(format_tokens ${total_balance})" ${ROW_LENGTH})"

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
