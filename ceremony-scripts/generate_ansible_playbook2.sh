#!/bin/bash

# USAGE: generate_ansible_goquorum_laybook.sh -v [Validator IP String] -r [RPC IP String]
#
# This script REQUIRES various environment variables to be set.

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX="0x4563918244f40000"
NETWORK_ISSUER_GAS_SEED_WEI_HEX="0x5d21dba00"

LOCKUP_SC_BALANCE=$(($NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX-${NETWORK_ISSUER_GAS_SEED_WEI_HEX}))
ISSUER_GAS_SEED_WEI=$(printf '%d\n' ${NETWORK_ISSUER_GAS_SEED_WEI_HEX})

VALIDATOR_IPS=""
## Let's do some admin work to find out the variables to be used here
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

[ -z "$VALIDATOR_IPS" ] && echo 'Missing -v' >&2 && help

# These environment variables have DEFAULT values if not set
[ -z "${DAO_CONTRACT_ARCHIVE_DIR}" ] && DAO_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_dao/$DAO_VERSION"
[ -z "${DAO_STORAGE_FILE}" ] && DAO_STORAGE_FILE="$DAO_CONTRACT_ARCHIVE_DIR/Storage.txt"
[ -z "${DAO_RUNTIME_BIN_FILE}" ] && DAO_RUNTIME_BIN_FILE="$DAO_CONTRACT_ARCHIVE_DIR/ValidatorSmartContractAllowList.bin-runtime"
[ -z "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] && LOCKUP_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_lockup/$LOCKUP_VERSION"
[ -z "${DIST_RUNTIME_BIN_FILE}" ] && DIST_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Distribution.bin-runtime"
[ -z "${DIST_OWNER_ADDRESS_FILE}" ] && DIST_OWNER_ADDRESS_FILE="$BASE_DIR/keys/distributionOwner/address"
[ -z "${LOCKUP_OWNER_ADDRESS_FILE}" ] && LOCKUP_OWNER_ADDRESS_FILE="$BASE_DIR/keys/lockupOwner/address"
[ -z "${LOCKUP_RUNTIME_BIN_FILE}" ] && LOCKUP_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Lockup.bin-runtime"
[ -z "${ANSIBLE_INSTALL_SCRIPT}" ] && ANSIBLE_INSTALL_SCRIPT="$BASE_DIR/ansible/install"

put_all_quorum_var() {
	VAR_NAME=$1
	VAR_VAL=$2

	mkdir -p ${ANSIBLE_DIR}/group_vars
	touch ${ANSIBLE_DIR}/group_vars/all_quorum.yml

	FILE_NAME=${ANSIBLE_DIR}/group_vars/all_quorum.yml
	if grep -q "${VAR_NAME}" "${FILE_NAME}"
	then
		sed -i "s/${VAR_NAME}:.*/${VAR_NAME}: ${VAR_VAL}/g" "${FILE_NAME}"
	else
		echo "${VAR_NAME}: ${VAR_VAL}" >> "${FILE_NAME}"
	fi
}

generate_enode_list() {
	BASE_KEYS_DIR=$BASE_DIR/keys
	LAST_IP=${VALIDATOR_IPS##* }
	COMMA=','
	for IP in ${VALIDATOR_IPS}; do
		# Set the comma to an empty sting for the last line.
		[ -z "${IP/$LAST_IP}" ] && COMMA=''
		public_key=$(cat ${BASE_KEYS_DIR}/${IP}/nodekey_pub)
		echo -n "\"enode://${public_key}@${IP}:40111\"${COMMA}"
	done
}

all_quorum_vars() {
	NOW=$(date +%s)
	NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

	put_all_quorum_var "goquorum_genesis_timestamp" "\"${NOW}\""
	put_all_quorum_var "lace_genesis_lockup_owner_address" "\"$(cat $LOCKUP_OWNER_ADDRESS_FILE)\""
  put_all_quorum_var "lace_genesis_lockup_last_dist_timestamp" "\"${NOW_IN_HEX#0x}\""
  put_all_quorum_var "lace_genesis_distribution_owner_address" "\"$(cat $DIST_OWNER_ADDRESS_FILE)\""
  put_all_quorum_var "lace_genesis_distribution_issuer_balance" "${ISSUER_GAS_SEED_WEI}"

	put_all_quorum_var "goquorum_genesis_sc_dao_code" "\"0x$(cat ${DAO_RUNTIME_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_lockup_code" "\"0x$(cat ${LOCKUP_RUNTIME_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_distribution_code" "\"0x$(cat ${DIST_RUNTIME_BIN_FILE})\""
	put_all_quorum_var "goquorum_genesis_sc_lockup_balance" "${LOCKUP_SC_BALANCE}"

	enode_list=$(generate_enode_list)
	echo "enode_list $enode_list"
	sed -i '/goquorum_enode_list/d' ${ANSIBLE_DIR}/group_vars/all_quorum.yml
	echo "goquorum_enode_list: [${enode_list}]" >> ${ANSIBLE_DIR}/group_vars/all_quorum.yml

	# Kinda janky, but gets the job done - grabs the contents of Storage.txt and puts it in a variable
	var="$(tail -n+6 ./contracts/sc_dao/v0.0.1/Storage.txt | head -n -2 | tr -d "[:blank:]\n")"
	sed -i '/goquorum_genesis_sc_dao_storage/d' ${ANSIBLE_DIR}/group_vars/all_quorum.yml
	echo "goquorum_genesis_sc_dao_storage: {${var}}" >> ${ANSIBLE_DIR}/group_vars/all_quorum.yml
}

cp -r ${BASE_DIR}/keys ${ANSIBLE_DIR}/keys

all_quorum_vars

if [ $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -s "Generated playbook"
else
   ${SCRIPTS_DIR}/printer.sh -e "Failed to generate playbook"
fi

