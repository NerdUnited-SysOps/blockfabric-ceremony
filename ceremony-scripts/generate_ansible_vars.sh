#!/usr/bin/env zsh

# USAGE: generate_ansible_goquorum_laybook.sh -v [Validator IP String]
#
# This script REQUIRES various environment variables to be set.

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
ENV_FILE="${BASE_DIR}/.env"
ETHKEY=${HOME}/go/bin/ethkey

BOLD='\e[1;31m'         # Bold Red
REV='\e[1;32m'       # Bold Green

help() {
	echo -e "${REV}Basic usage:${OFF} ${BOLD}$SCRIPT -v <"value"> -r <"value"> command ${OFF}"\\n
	echo -e "${REV}The following switches are recognized. $OFF "
	echo -e "${REV}-v                   ${OFF}Validator Node IP List"
	echo -e "${REV}-h                   ${OFF}Displays this help message. No further functions are performed."\\n
	exit 1
}

OPTSPEC=":hv:r:"
while getopts "$OPTSPEC" optchar; do
	case "${optchar}" in
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
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

printer -t "Creating ansible vars"

[ -z "$VALIDATOR_IPS" ] && echo 'Missing -v' >&2 && help

# These environment variables have DEFAULT values if not set
[ -z "${DAO_CONTRACT_ARCHIVE_DIR}" ] && DAO_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_dao/$DAO_VERSION"
[ -z "${DAO_RUNTIME_BIN_FILE}" ] && DAO_RUNTIME_BIN_FILE="$DAO_CONTRACT_ARCHIVE_DIR/ValidatorSmartContractAllowList.bin-runtime"
[ -z "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] && LOCKUP_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_lockup/$LOCKUP_VERSION"
[ -z "${DIST_RUNTIME_BIN_FILE}" ] && DIST_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Distribution.bin-runtime"
[ -z "${DIST_OWNER_ADDRESS_FILE}" ] && DIST_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume1/distributionOwner"
[ -z "${DIST_ISSUER_ADDRESS_FILE}" ] && DIST_ISSUER_ADDRESS_FILE="$BASE_DIR/volumes/volume1/distributionIssuer"
[ -z "${LOCKUP_OWNER_ADDRESS_FILE}" ] && LOCKUP_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume1/lockupOwner"
[ -z "${LOCKUP_RUNTIME_BIN_FILE}" ] && LOCKUP_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Lockup.bin-runtime"

[ -z "${BRIDGE_APPROVER_ADDRESS_FILE}" ] && BRIDGE_APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_approver/keystore"
[ -z "${BRIDGE_NOTARY_ADDRESS_FILE}" ] && BRIDGE_NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_notary/keystore"
[ -z "${BRIDGE_FEE_RECEIVER_ADDRESS_FILE}" ] && BRIDGE_FEE_RECEIVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_fee_receiver/keystore"
[ -z "${TOKEN_OWNER_ADDRESS_FILE}" ] && TOKEN_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/token_owner/keystore"
[ -z "${BRIDGE_MINTER_APPROVER_ADDRESS_FILE}" ] && BRIDGE_MINTER_APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_minter_approver/keystore"
[ -z "${BRIDGE_MINTER_NOTARY_ADDRESS_FILE}"   ] && BRIDGE_MINTER_NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_minter_notary/keystore"

check_file() {
	file_name=$1
	file_path=$2

	if [ ! -f "${file_path}" ]; then
		printer -e "Missing ${file_name}. Expected it here: ${file_path}"
	fi
}

# Validate that the expected files are in place
check_file "DAO bytecode" "${DAO_RUNTIME_BIN_FILE}"
check_file "Lockup bytecode" "${LOCKUP_RUNTIME_BIN_FILE}"
check_file "Distirbution bytecode" "${DIST_RUNTIME_BIN_FILE}"
check_file "Distribution owner address" "${DIST_OWNER_ADDRESS_FILE}/keystore"
check_file "distribution issuer address" "${DIST_ISSUER_ADDRESS_FILE}/keystore"
check_file "Lockup owner address" "${LOCKUP_OWNER_ADDRESS_FILE}/keystore"

check_file "Bridge approver address"  "${BRIDGE_APPROVER_ADDRESS_FILE}"
check_file "Bridge notary address"  "${BRIDGE_NOTARY_ADDRESS_FILE}"
check_file "Bridge fee receiver address"  "${BRIDGE_FEE_RECEIVER_ADDRESS_FILE}"
check_file "Token address"  "${TOKEN_OWNER_ADDRESS_FILE}"
check_file "Bridge minter approver address"  "${BRIDGE_MINTER_APPROVER_ADDRESS_FILE}"
check_file "Bridge minter notary address"  "${BRIDGE_MINTER_NOTARY_ADDRESS_FILE}"


put_all_quorum_var() {
	VAR_NAME=$1
	VAR_VAL=$2

	mkdir -p ${ANSIBLE_DIR}/group_vars
	touch ${ANSIBLE_DIR}/group_vars/all_quorum.yml

	FILE_NAME=${ANSIBLE_DIR}/group_vars/all_quorum.yml
	if grep -q "^${VAR_NAME}" "${FILE_NAME}"
	then
		sed -i "s/${VAR_NAME}:.*/${VAR_NAME}: ${VAR_VAL}/g" "${FILE_NAME}"
	else
		echo "${VAR_NAME}: ${VAR_VAL}" >> "${FILE_NAME}"
	fi
}

inspect() {
	inspect_path=$1

	${ETHKEY} inspect \
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

generate_enode_list() {
	BASE_KEYS_DIR=$BASE_DIR/volumes/volume1
	LAST_IP=${VALIDATOR_IPS##* }
	COMMA=','
	ips=(${(@s: :)VALIDATOR_IPS})
	for IP in ${ips}; do
		# Set the comma to an empty sting for the last line.
		[ -z "${IP/$LAST_IP}" ] && COMMA=''
		public_key=$(get_public_key "${BASE_KEYS_DIR}/${IP}/node")
		echo -n "\"enode://${public_key}@${IP}:40111\"${COMMA}"
	done
}

all_quorum_vars() {
	if [ -n "${NODE_USER}" ]; then
		put_all_quorum_var "ansible_user" "${NODE_USER}"
	fi
	put_all_quorum_var "lace_genesis_lockup_owner_address" "\"$(get_address $LOCKUP_OWNER_ADDRESS_FILE)\""
  put_all_quorum_var "lace_genesis_distribution_owner_address" "\"$(get_address $DIST_OWNER_ADDRESS_FILE)\""
  put_all_quorum_var "lace_genesis_distribution_issuer_address" "\"$(get_address $DIST_ISSUER_ADDRESS_FILE | cut -c3-)\""



# TODO: read address, store in appropriate role var
#echo "${BRIDGE_APPROVER_ADDRESS_FILE}       $(get_address $BRIDGE_APPROVER_ADDRESS_FILE)"
#echo "${BRIDGE_NOTARY_ADDRESS_FILE}         $(get_address $BRIDGE_NOTARY_ADDRESS_FILE)"
#echo "${BRIDGE_FEE_RECEIVER_ADDRESS_FILE}   $(get_address $BRIDGE_FEE_RECEIVER_ADDRESS_FILE)"
#echo "${TOKEN_OWNER_ADDRESS_FILE}           $(get_address $TOKEN_OWNER_ADDRESS_FILE)"
#echo "${BRIDGE_MINTER_APPROVER_ADDRESS_FILE}$(get_address $BRIDGE_MINTER_APPROVER_ADDRESS_FILE)"
#echo "${BRIDGE_MINTER_NOTARY_ADDRESS_FILE}  $(get_address $BRIDGE_MINTER_NOTARY_ADDRESS_FILE)"


	put_all_quorum_var "goquorum_genesis_sc_dao_code" "\"0x$(cat ${DAO_RUNTIME_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_lockup_code" "\"0x$(cat ${LOCKUP_RUNTIME_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_distribution_code" "\"0x$(cat ${DIST_RUNTIME_BIN_FILE})\""

	admin_addresses=$(${SCRIPTS_DIR}/create_lockup_storage/create_lockup_storage.sh)
	sc_lockup_storage=$(echo "{ \"0x0000000000000000000000000000000000000000000000000000000000000000\": \"{{ lace_genesis_lockup_owner_address }}\", \"0x0000000000000000000000000000000000000000000000000000000000000002\": \"{{ lace_genesis_lockup_issuer_address }}\", \"0x0000000000000000000000000000000000000000000000000000000000000004\": \"{{ lace_genesis_lockup_daily_limit }}\", \"0x0000000000000000000000000000000000000000000000000000000000000005\": \"{{ lace_genesis_lockup_last_dist_timestamp }}\", ${admin_addresses} }")

	sed -i '/goquorum_genesis_sc_lockup_storage/d' ${ANSIBLE_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_lockup_storage: ${sc_lockup_storage}" >> ${ANSIBLE_DIR}/group_vars/all_quorum.yml

	enode_list=$(generate_enode_list)
	sed -i '/goquorum_enode_list/d' ${ANSIBLE_DIR}/group_vars/all_quorum.yml
	echo "goquorum_enode_list: [${enode_list}]" >> ${ANSIBLE_DIR}/group_vars/all_quorum.yml

	# Kinda janky, but gets the job done - grabs the contents of Storage.txt and puts it in a variable
	var="$(tail -n+6 ./contracts/sc_dao/$DAO_VERSION/Storage.txt | head -n -2 | tr -d "[:blank:]\n")"
	sed -i '/goquorum_genesis_sc_dao_storage/d' ${ANSIBLE_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_dao_storage: {${var}}" >> ${ANSIBLE_DIR}/group_vars/all_quorum.yml
}

BASE_KEYS_DIR=$BASE_DIR/volumes/volume1
ANSIBLE_KEY_DIR=${ANSIBLE_DIR}/keys
ips=(${(@s: :)VALIDATOR_IPS})
for IP in ${ips}; do
	mkdir -p ${ANSIBLE_KEY_DIR}/${IP}
	nodekey=$(get_private_key "${BASE_KEYS_DIR}/${IP}/node")
	echo "${nodekey}" > "${ANSIBLE_KEY_DIR}/${IP}/nodekey"
done

all_quorum_vars

if [ $? -eq 0 ]; then
   printer -s "Generated variables"
else
   printer -e "Failed to generate variables"
fi

