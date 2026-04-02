#!/usr/bin/env zsh

# USAGE: generate_ansible_goquorum_laybook.sh -v [Validator IP String]
#
# This script REQUIRES various environment variables to be set.

set -e

BOLD='\e[1;31m'         # Bold Red
REV='\e[1;32m'       # Bold Green

help() {
	echo -e "${REV}Basic usage:${OFF} ${BOLD}$SCRIPT -v <"value"> -r <"value"> command ${OFF}"\\n
	echo -e "${REV}The following switches are recognized. $OFF "
	echo -e "${REV}-v                   ${OFF}Validator Node IP List"
	echo -e "${REV}-h                   ${OFF}Displays this help message. No further functions are performed."\\n
	exit 1
}


while getopts e:hv:r: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		v)
			VALIDATOR_IPS+=$OPTARG
			;;
		h)
			help
			;;
		\?) #unrecognized option - show help
			echo -e "\nOption -${BOLD}$OPTARG${OFF} not allowed.\n"
			help
			;;
	esac
done

shift "$(( OPTIND - 1 ))"

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${ANSIBLE_DIR}" ]] && echo ".env is missing ANSIBLE_DIR variable" && exit 1
[[ ! -d "${ANSIBLE_DIR}" ]] && echo "ANSIBLE_DIR environment variable is not a directory. Expecting it here ${ANSIBLE_DIR}" && exit 1

[[ -z "${ETHKEY_PATH}" ]] && echo ".env is missing ETHKEY_PATH variable" && exit 1
[[ ! -f "${ETHKEY_PATH}" ]] && echo "ETHKEY_PATH environment variable is not a file. Expecting it here ${ETHKEY_PATH}" && exit 1

[[ -z "${DISTRIBUTION_CONTRACT_BALANCE}" ]] && echo "${0}:${LINENO} .env is missing DISTRIBUTION_CONTRACT_BALANCE variable" && exit 1

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

printer -t "Creating ansible vars"

[ -z "$VALIDATOR_IPS" ] && echo 'Missing -v' >&2 && help

# These environment variables have DEFAULT values if not set
[ -z "${DAO_CONTRACT_ARCHIVE_DIR}" ] && DAO_CONTRACT_ARCHIVE_DIR="$CONTRACTS_DIR/sc_dao/$DAO_VERSION"
[ -z "${DAO_RUNTIME_BIN_FILE}" ] && DAO_RUNTIME_BIN_FILE="$DAO_CONTRACT_ARCHIVE_DIR/ValidatorSmartContractAllowList.bin-runtime"
[ -z "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] && LOCKUP_CONTRACT_ARCHIVE_DIR="$CONTRACTS_DIR/sc_lockup/$LOCKUP_VERSION"
[ -z "${DIST_RUNTIME_BIN_FILE}" ] && DIST_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Distribution.bin-runtime"
[ -z "${LOCKUP_RUNTIME_BIN_FILE}" ] && LOCKUP_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Lockup.bin-runtime"
[ -z "${DIST_ISSUER_ADDRESS_FILE}" ] && DIST_ISSUER_ADDRESS_FILE="$VOLUMES_DIR/volume2/distributionIssuer"
[ -z "${SAFE_OWNER_1_ADDRESS_FILE}" ] && SAFE_OWNER_1_ADDRESS_FILE="$VOLUMES_DIR/volume1/lockupOwner1"
[ -z "${SAFE_OWNER_2_ADDRESS_FILE}" ] && SAFE_OWNER_2_ADDRESS_FILE="$VOLUMES_DIR/volume2/lockupOwner2"
[ -z "${SAFE_OWNER_3_ADDRESS_FILE}" ] && SAFE_OWNER_3_ADDRESS_FILE="$VOLUMES_DIR/volume3/lockupOwner3"
[ -z "${SAFE_CONTRACT_ARCHIVE_DIR}" ] && SAFE_CONTRACT_ARCHIVE_DIR="$CONTRACTS_DIR/${GITHUB_SAFE_REPO}/$SAFE_VERSION"
[ -z "${SAFE_SINGLETON_BIN_FILE}" ] && SAFE_SINGLETON_BIN_FILE="$SAFE_CONTRACT_ARCHIVE_DIR/GnosisSafe.bin-runtime"
[ -z "${SAFE_PROXY_BIN_FILE}" ] && SAFE_PROXY_BIN_FILE="$SAFE_CONTRACT_ARCHIVE_DIR/GnosisSafeProxy.bin-runtime"


check_file() {
	file_name=$1
	file_path=$2

	[[ -z "${file_path}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} empty variable ${file_name}"

	if [ ! -f "${file_path}" ]; then
		printer -e "Missing ${file_name}. Expected it here: ${file_path}"
	fi
}

# Validate that the expected files are in place
check_file "DAO bytecode" "${DAO_RUNTIME_BIN_FILE}"
check_file "Lockup bytecode" "${LOCKUP_RUNTIME_BIN_FILE}"
check_file "Distirbution bytecode" "${DIST_RUNTIME_BIN_FILE}"
check_file "Safe singleton bytecode" "${SAFE_SINGLETON_BIN_FILE}"
check_file "Safe proxy bytecode" "${SAFE_PROXY_BIN_FILE}"
check_file "distribution issuer address" "${DIST_ISSUER_ADDRESS_FILE}/keystore"
check_file "Safe owner 1 address" "${SAFE_OWNER_1_ADDRESS_FILE}/keystore"
check_file "Safe owner 2 address" "${SAFE_OWNER_2_ADDRESS_FILE}/keystore"
check_file "Safe owner 3 address" "${SAFE_OWNER_3_ADDRESS_FILE}/keystore"

put_all_quorum_var() {
	VAR_NAME=$1
	VAR_VAL=$2

	mkdir -p ${ANSIBLE_CEREMONY_DIR}/group_vars
	touch ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml

	FILE_NAME=${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	if grep -q "^${VAR_NAME}" "${FILE_NAME}"
	then
		sed -i "\\|^${VAR_NAME}:|s|.*|${VAR_NAME}: ${VAR_VAL}|" "${FILE_NAME}"
	else
		echo "${VAR_NAME}: ${VAR_VAL}" >> "${FILE_NAME}"
	fi
}

inspect() {
	inspect_path=$1

	${ETHKEY_PATH} inspect \
		--private \
		--passwordfile ${inspect_path}/password \
		${inspect_path}/keystore
}

get_private_key() {
	inspect_path=$1
	inspected_content=$(inspect "${inspect_path}")
	echo "${inspected_content}" | sed -n "s/Private\skey:\s*\(.*\)/\1/p" | tr -d '\n'
}

get_public_key() {
	inspect_path=$1
	inspected_content=$(inspect "${inspect_path}")
	echo "${inspected_content}" | sed -n "s/Public\skey:\s*04\(.*\)/\1/p" | tr -d '\n'
}

get_address() {
	inspect_path=$1
	inspected_content=$(inspect "${inspect_path}")
	echo "${inspected_content}" | sed -n "s/Address:\s*\(.*\)/\1/p" | tr -d '\n'
}

# Format an address for genesis storage: strip 0x, lowercase, left-pad to 64 chars
format_storage_addr() {
	local addr=$(echo "$1" | sed 's/^0x//' | tr 'A-F' 'a-f')
	printf "%064s" "$addr" | tr ' ' '0'
}

# Format a decimal number for genesis storage: convert to hex, left-pad to 64 chars
# Uses python3 because values like token supplies in wei exceed zsh's 64-bit integer limit
format_storage_num() {
	python3 -c "print(format(int('$1'), '064x'))"
}

# Resolve a hostname to its ansible_host IP from the inventory file.
# If the hostname is already an IP or not found, returns it unchanged.
resolve_ip() {
	local hostname=$1
	local resolved=$(grep "^${hostname}\b" "${INVENTORY_PATH}" | grep -oP 'ansible_host=\K\S+')
	echo "${resolved:-$hostname}"
}

generate_enode_list() {
	BASE_KEYS_DIR=${VOLUMES_DIR}/volume1
	LAST_IP=${VALIDATOR_IPS##* }
	COMMA=','
	ips=(${(@s: :)VALIDATOR_IPS})
	for IP in ${ips}; do
		# Set the comma to an empty sting for the last line.
		[ -z "${IP/$LAST_IP}" ] && COMMA=''
		public_key=$(get_public_key "${BASE_KEYS_DIR}/${IP}/node")
		resolved_ip=$(resolve_ip "${IP}")
		echo -n "\"enode://${public_key}@${resolved_ip}:40111\"${COMMA}"
	done
}

all_quorum_vars() {
	if [ -n "${NODE_USER}" ]; then
		put_all_quorum_var "ansible_user" "${NODE_USER}"
	fi
	# Set the timestamp of the genesis block to now
	put_all_quorum_var "goquorum_genesis_timestamp" "\"$(date +%s)\""
	# Safe proxy address is the owner of both lockup and distribution
	put_all_quorum_var "lace_genesis_lockup_owner_address" "\"${SAFE_PROXY_ADDRESS}\""
	put_all_quorum_var "lace_genesis_distribution_owner_address" "\"${SAFE_PROXY_ADDRESS}\""
	put_all_quorum_var "lace_genesis_distribution_issuer_address" "\"$(get_address $DIST_ISSUER_ADDRESS_FILE | cut -c3-)\""
	# Lockup issuer = distribution contract address (0x8Be5...)
	put_all_quorum_var "lace_genesis_lockup_issuer_address" "\"8Be503bcdEd90ED42Eff31f56199399B2b0154CA\""

	put_all_quorum_var "goquorum_genesis_sc_dao_code" "\"0x$(cat ${DAO_RUNTIME_BIN_FILE})\""

	# Patch lockup bytecode: embed immutable values (owner, initialDistribution)
	# Immutable offsets from solc --standard-json immutableReferences:
	#   owner (address):            bytes 479, 622, 1253
	#   initialDistribution (uint): bytes 1375, 1428, 1660, 1708, 1810, 1941
	lockup_bytecode=$(cat ${LOCKUP_RUNTIME_BIN_FILE})
	padded_owner=$(format_storage_addr "${SAFE_PROXY_ADDRESS}")
	padded_timestamp=$(format_storage_num "${LOCKUP_TIMESTAMP}")
	lockup_bytecode=$(python3 -c "
bc = '${lockup_bytecode}'
owner = '${padded_owner}'
ts = '${padded_timestamp}'
# Each byte offset = 2 hex chars
for off in [479, 622, 1253]:
    h = off * 2
    bc = bc[:h] + owner + bc[h+64:]
for off in [1375, 1428, 1660, 1708, 1810, 1941]:
    h = off * 2
    bc = bc[:h] + ts + bc[h+64:]
print(bc)
")
	put_all_quorum_var "goquorum_genesis_sc_lockup_code" "\"0x${lockup_bytecode}\""
	# Patch distribution bytecode: embed immutable values (owner, lockup)
	# Immutable offsets from solc --standard-json immutableReferences:
	#   owner (address):  bytes 215, 1025
	#   lockup (address): byte 331
	dist_bytecode=$(cat ${DIST_RUNTIME_BIN_FILE})
	padded_dist_owner=$(format_storage_addr "${SAFE_PROXY_ADDRESS}")
	padded_lockup_addr=$(format_storage_addr "47e9Fbef8C83A1714F1951F142132E6e90F5fa5D")
	dist_bytecode=$(python3 -c "
bc = '${dist_bytecode}'
owner = '${padded_dist_owner}'
lockup = '${padded_lockup_addr}'
for off in [215, 1025]:
    h = off * 2
    bc = bc[:h] + owner + bc[h+64:]
for off in [331]:
    h = off * 2
    bc = bc[:h] + lockup + bc[h+64:]
print(bc)
")
	put_all_quorum_var "goquorum_genesis_sc_distribution_code" "\"0x${dist_bytecode}\""
	put_all_quorum_var "goquorum_genesis_sc_safe_singleton_code" "\"0x$(cat ${SAFE_SINGLETON_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_safe_proxy_code" "\"0x$(cat ${SAFE_PROXY_BIN_FILE})\""

	# Compute Safe storage (owners linked list, threshold, singleton pointer)
	safe_owner_1=$(get_address $SAFE_OWNER_1_ADDRESS_FILE)
	safe_owner_2=$(get_address $SAFE_OWNER_2_ADDRESS_FILE)
	safe_owner_3=$(get_address $SAFE_OWNER_3_ADDRESS_FILE)

	GO_CMD_DIR=${SCRIPTS_DIR}/cmd
	sc_safe_storage=$(cd ${GO_CMD_DIR} && go run ./safe_storage ${SAFE_SINGLETON_ADDRESS} ${SAFE_THRESHOLD:-2} $safe_owner_1 $safe_owner_2 $safe_owner_3)

	# Lockup storage: owner = Safe proxy, no admins mapping
	lockup_owner="${SAFE_PROXY_ADDRESS}"
	lockup_issuer="8Be503bcdEd90ED42Eff31f56199399B2b0154CA"  # distribution contract
	lockup_daily_limit=${GENESIS_LOCKUP_DAILY_LIMIT}
	lockup_timestamp=${LOCKUP_TIMESTAMP}

	# Storage layout (no admins mapping):
	#   slot 0: issuer (address, 20 bytes) + paused (bool, 1 byte) - packed
	#   slot 1: amount (uint256) - defaults to 0, omitted
	#   slot 2: dailyLimit (uint256)
	#   slot 3: lastDistribution (uint256)
	#   immutables (owner, initialDistribution) are in bytecode, not storage
	sc_lockup_storage="{ \"$(printf '%064x' 0)\": \"$(format_storage_addr $lockup_issuer)\", \"$(printf '%064x' 2)\": \"$(format_storage_num $lockup_daily_limit)\", \"$(printf '%064x' 3)\": \"$(format_storage_num $lockup_timestamp)\" }"

	# Creates a set of wallets - only use for testnets
	put_all_quorum_var "create_genesis_test_wallets" "${TEST_WALLETS}"
	put_all_quorum_var "lace_genesis_lockup_last_dist_timestamp" "\"${LOCKUP_TIMESTAMP}\""
	put_all_quorum_var "total_coin_supply" "${TOTAL_COIN_SUPPLY}"
	put_all_quorum_var "lace_genesis_distribution_issuer_balance" "${DISTIRBUTION_ISSUER_BALANCE}"
	put_all_quorum_var "goquorum_genesis_sc_distribution_balance" "${DISTRIBUTION_CONTRACT_BALANCE}"

	# Distribution storage: owner (slot 0), issuer (slot 1), lockup address (slot 2)
	dist_owner="${SAFE_PROXY_ADDRESS}"
	dist_issuer=$(get_address $DIST_ISSUER_ADDRESS_FILE)
	dist_lockup="47e9Fbef8C83A1714F1951F142132E6e90F5fa5D"  # lockup contract

	sc_distribution_storage="{ \"$(printf '%064x' 0)\": \"$(format_storage_addr $dist_owner)\", \"$(printf '%064x' 1)\": \"$(format_storage_addr $dist_issuer)\", \"$(printf '%064x' 2)\": \"$(format_storage_addr $dist_lockup)\" }"

	sed -i '/goquorum_genesis_sc_distribution_storage/d' ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_distribution_storage: ${sc_distribution_storage}" >> ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml

	# Lockup balance = total supply - distribution contract - distribution issuer
	# Use python3 for arbitrary-precision arithmetic (values exceed zsh int64)
	local lockup_balance=$(python3 -c "print(${TOTAL_COIN_SUPPLY} - ${DISTRIBUTION_CONTRACT_BALANCE} - ${DISTIRBUTION_ISSUER_BALANCE})")
	put_all_quorum_var "goquorum_genesis_sc_lockup_balance" "${lockup_balance}"
	put_all_quorum_var "goquorum_network_id" "${CHAIN_ID}"
	put_all_quorum_var "besu_network_id" "${CHAIN_ID}"
	put_all_quorum_var "goquorum_identity" "${CHAIN_NAME}_${NETWORK_TYPE}_{{ inventory_hostname }}"
	put_all_quorum_var "lace_genesis_lockup_daily_limit" "\"${GENESIS_LOCKUP_DAILY_LIMIT}\""

	sed -i '/goquorum_genesis_sc_lockup_storage/d' ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_lockup_storage: ${sc_lockup_storage}" >> ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml

	sed -i '/goquorum_genesis_sc_safe_storage/d' ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_safe_storage: ${sc_safe_storage}" >> ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml

	put_all_quorum_var "goquorum_genesis_sc_safe_singleton_address" "\"${SAFE_SINGLETON_ADDRESS}\""
	put_all_quorum_var "goquorum_genesis_sc_safe_proxy_address" "\"${SAFE_PROXY_ADDRESS}\""

	enode_list=$(generate_enode_list)
	sed -i '/goquorum_enode_list/d' ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	echo "goquorum_enode_list: [${enode_list}]" >> ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml

	# Kinda janky, but gets the job done - grabs the contents of Storage.txt and puts it in a variable
	var="$(tail -n+6 $CONTRACTS_DIR/sc_dao/$DAO_VERSION/Storage.txt | head -n -2 | tr -d "[:blank:]\n")"
	sed -i '/goquorum_genesis_sc_dao_storage/d' ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_dao_storage: {${var}}" >> ${ANSIBLE_CEREMONY_DIR}/group_vars/all_quorum.yml
}

BASE_KEYS_DIR=${VOLUMES_DIR}/volume1
ANSIBLE_KEY_DIR=${ANSIBLE_CEREMONY_DIR}/keys
ips=(${(@s: :)VALIDATOR_IPS})
for IP in ${ips}; do
	mkdir -p ${ANSIBLE_KEY_DIR}/${IP}
	nodekey=$(get_private_key "${BASE_KEYS_DIR}/${IP}/node")
	echo "${nodekey}" > "${ANSIBLE_KEY_DIR}/${IP}/nodekey"
done

put_all_quorum_var "besu_keys_dir" "$(realpath ${ANSIBLE_CEREMONY_DIR}/keys)"
put_all_quorum_var "besu_genesis_validator_contract_address" "\"0x5a443704dd4B594B382c22a083e2BD3090A6feF3\""
rm -f "${ANSIBLE_DIR}/group_vars/besu/network.yml"  # clean stale besu-keygen output (brand repo download)
rm -f "${BESU_ROLE_INSTALL_PATH}/test/group_vars/besu/network.yml"  # clean stale besu-keygen output (git clone)

all_quorum_vars

if [ $? -eq 0 ]; then
   printer -s "Generated variables"
else
   printer -e "Failed to generate variables"
fi
