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
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${NODE_USER}" ]] && echo "${0}:${LINENO} .env is missing NODE_USER variable" && exit 1
[[ -z "${VOLUMES_DIR}" ]] && echo "${0}:${LINENO} .env is missing VOLUMES_DIR variable" && exit 1
[[ -z "${TOTAL_COIN_SUPPLY}" ]] && echo "${0}:${LINENO} .env is missing TOTAL_COIN_SUPPLY variable" && exit 1
[[ -z "${DISTRIBUTION_CONTRACT_BALANCE}" ]] && echo "${0}:${LINENO} .env is missing DISTRIBUTION_CONTRACT_BALANCE variable" && exit 1
[[ -z "${DISTIRBUTION_ISSUER_BALANCE}" ]] && echo "${0}:${LINENO} .env is missing DISTIRBUTION_ISSUER_BALANCE variable" && exit 1

SSH_OPTS=(-q -o LogLevel=quiet -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "${AWS_NODES_SSH_KEY_PATH}")

# Contract addresses (hardcoded in genesis)
DAO_ADDRESS="5a443704dd4B594B382c22a083e2BD3090A6feF3"
LOCKUP_ADDRESS="47e9Fbef8C83A1714F1951F142132E6e90F5fa5D"
DISTRIBUTION_ADDRESS="8Be503bcdEd90ED42Eff31f56199399B2b0154CA"

# DAO validator array base slot: keccak256(uint256(0)) — constant
DAO_ARRAY_BASE="290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563"

# Get first host from an inventory group, resolved to its ansible_host IP
get_first_host() {
	local group=$1
	local host=$(ansible --list-hosts -i ${INVENTORY_PATH} ${group} 2>/dev/null | sed '/:/d ; s/ //g' | head -1)
	[[ -z "${host}" ]] && return

	local resolved=$(ansible-inventory -i ${INVENTORY_PATH} --host "${host}" 2>/dev/null | jq -r '.ansible_host // empty')
	[[ -n "${resolved}" ]] && echo "${resolved}" || echo "${host}"
}

# Get all hostnames from an inventory group (not resolved — we need inventory_hostname for volume dirs)
get_group_hosts() {
	local group=$1
	ansible --list-hosts -i ${INVENTORY_PATH} ${group} 2>/dev/null | sed '/:/d ; s/ //g'
}

# Extract address from keystore file (40-char lowercase hex, no 0x prefix)
get_keystore_address() {
	local keystore_file=$1
	grep -o '"address": *"[^"]*"' "${keystore_file}" | grep -o '"[^"]*"$' | sed 's/"//g'
}

# Fetch genesis.json from a node via SSH
node_ip=$(get_first_host rpc)
[[ -z "${node_ip}" ]] && node_ip=$(get_first_host validator)
[[ -z "${node_ip}" ]] && echo "No hosts found in inventory" && exit 1

genesis_json=$(ssh ${SSH_OPTS[@]} "${NODE_USER}@${node_ip}" "sudo cat /etc/besu/genesis.json" 2>/dev/null)

if [[ -z "${genesis_json}" ]]; then
	echo "Error: Could not read genesis.json from ${node_ip}"
	exit 1
fi

# Get validator hostnames from inventory
validator_hosts=($(get_group_hosts validator))
validator_count=${#validator_hosts[@]}

if [[ ${validator_count} -eq 0 ]]; then
	echo "Error: No validators found in inventory"
	exit 1
fi

# Build JSON object of expected addresses from ceremony artifacts
# Format: {"hostname": {"validator": "addr", "account": "addr"}, ...}
expected_json="{"
first=true
for host in "${validator_hosts[@]}"; do
	host_dir="${VOLUMES_DIR}/volume1/${host}"
	node_addr=""
	account_addr=""

	if [[ -f "${host_dir}/node/keystore" ]]; then
		node_addr=$(get_keystore_address "${host_dir}/node/keystore")
	else
		echo "Warning: Missing node keystore for ${host} at ${host_dir}/node/keystore"
	fi
	if [[ -f "${host_dir}/account/keystore" ]]; then
		account_addr=$(get_keystore_address "${host_dir}/account/keystore")
	else
		echo "Warning: Missing account keystore for ${host} at ${host_dir}/account/keystore"
	fi

	if [[ "${first}" != "true" ]]; then
		expected_json="${expected_json},"
	fi
	expected_json="${expected_json}\"${host}\":{\"validator\":\"${node_addr}\",\"account\":\"${account_addr}\"}"
	first=false
done
expected_json="${expected_json}}"

# Get distribution issuer address from volume2
dist_issuer_address=""
if [[ -f "${VOLUMES_DIR}/volume2/distributionIssuer/keystore" ]]; then
	dist_issuer_address=$(get_keystore_address "${VOLUMES_DIR}/volume2/distributionIssuer/keystore")
fi

# Write genesis to temp file (too large for argv)
genesis_tmp=$(mktemp)
echo "${genesis_json}" > "${genesis_tmp}"
trap "rm -f ${genesis_tmp}" EXIT

# Run all checks via embedded python3
python3 - "${genesis_tmp}" "${TOTAL_COIN_SUPPLY}" "${DISTRIBUTION_CONTRACT_BALANCE}" "${DISTIRBUTION_ISSUER_BALANCE}" \
	"${DAO_ADDRESS}" "${LOCKUP_ADDRESS}" "${DISTRIBUTION_ADDRESS}" "${DAO_ARRAY_BASE}" \
	"${dist_issuer_address}" "${validator_count}" "${expected_json}" <<'PYEOF'
import json
import sys

with open(sys.argv[1]) as f:
    genesis = json.load(f)

total_coin_supply = int(sys.argv[2])
dist_contract_balance_expected = int(sys.argv[3])
dist_issuer_balance_expected = int(sys.argv[4])
dao_addr = sys.argv[5].lower()
lockup_addr = sys.argv[6].lower()
dist_addr = sys.argv[7].lower()
dao_array_base = sys.argv[8].lower()
dist_issuer_addr = sys.argv[9].lower()
validator_count = int(sys.argv[10])
expected = json.loads(sys.argv[11])

# Normalize alloc keys to lowercase without 0x
alloc = {}
for k, v in genesis.get("alloc", {}).items():
    alloc[k.lower().replace("0x", "")] = v

passed = 0
total = 0
results = []

def check(label, ok, detail=""):
    global passed, total
    total += 1
    status = "PASS" if ok else "FAIL"
    if ok:
        passed += 1
    if detail:
        results.append(f" {label:<40} {status}  ({detail})")
    else:
        results.append(f" {label:<40} {status}")

# ---------------------------------------------------------------
# Check 1: Balances
# ---------------------------------------------------------------

# Distribution contract balance
dist_alloc = alloc.get(dist_addr, {})
dist_balance_genesis = int(dist_alloc.get("balance", "0"))
check("Balance: Distribution Contract",
      dist_balance_genesis == dist_contract_balance_expected,
      str(dist_balance_genesis))

# Distribution issuer balance
issuer_alloc = alloc.get(dist_issuer_addr, {})
issuer_balance_genesis = int(issuer_alloc.get("balance", "0"))
check("Balance: Distribution Issuer",
      issuer_balance_genesis == dist_issuer_balance_expected,
      str(issuer_balance_genesis))

# Lockup balance = total - distribution contract - distribution issuer
expected_lockup = total_coin_supply - dist_contract_balance_expected - dist_issuer_balance_expected
lockup_alloc = alloc.get(lockup_addr, {})
lockup_balance_genesis = int(lockup_alloc.get("balance", "0"))
check("Balance: Lockup Contract",
      lockup_balance_genesis == expected_lockup,
      str(lockup_balance_genesis))

# ---------------------------------------------------------------
# Check 2: DAO validators match nodekeys
# ---------------------------------------------------------------

dao_alloc = alloc.get(dao_addr, {})
dao_storage = dao_alloc.get("storage", {})

# Normalize storage keys: strip 0x prefix, lowercase
norm_storage = {}
for k, v in dao_storage.items():
    norm_storage[k.lower().replace("0x", "")] = v.lower().replace("0x", "")

# Slot 0 = validator count
slot_0_key = "0" * 64
dao_validator_count_hex = norm_storage.get(slot_0_key, "0")
dao_validator_count = int(dao_validator_count_hex, 16) if dao_validator_count_hex != "0" else 0
check("DAO: Validator count",
      dao_validator_count == validator_count,
      str(dao_validator_count))

# Read validator addresses from sequential array slots
dao_validators = set()
base = int(dao_array_base, 16)
for i in range(dao_validator_count):
    slot_key = format(base + i, "064x")
    val = norm_storage.get(slot_key, "")
    if val:
        dao_validators.add(val[-40:])

# Compare each expected validator
for hostname in sorted(expected.keys()):
    addr = expected[hostname]["validator"].lower()
    found = addr in dao_validators
    check(f"DAO: {hostname} validator",
          found,
          addr[:12] + "...")

# ---------------------------------------------------------------
# Check 3: DAO account owners match account keys
# ---------------------------------------------------------------

# Slot 3 = allowed account count
slot_3_key = "0" * 63 + "3"
dao_account_count_hex = norm_storage.get(slot_3_key, "0")
dao_account_count = int(dao_account_count_hex, 16) if dao_account_count_hex != "0" else 0
check("DAO: Account count",
      dao_account_count == validator_count,
      str(dao_account_count))

# Scan all DAO storage values for expected account addresses
all_storage_values = set()
for v in norm_storage.values():
    if len(v) >= 40:
        all_storage_values.add(v[-40:])

for hostname in sorted(expected.keys()):
    addr = expected[hostname]["account"].lower()
    found = addr in all_storage_values
    check(f"DAO: {hostname} account",
          found,
          addr[:12] + "...")

# ---------------------------------------------------------------
# Print results
# ---------------------------------------------------------------

print("")
print("------------------------------------------------------------------")
print(" Genesis Validation")
print("------------------------------------------------------------------")
for r in results:
    print(r)
print("------------------------------------------------------------------")
print(f" Result: {passed}/{total} passed")
print("------------------------------------------------------------------")
print("")

sys.exit(0 if passed == total else 1)
PYEOF
