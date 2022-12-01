#!/bin/bash

IP_ADDRESS_LIST=${1:?ERROR: Missing IP Address list}

echo "Generating validator and account wallets"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

for ip in ${IP_ADDRESS_LIST}
do
	echo "Setting up keys for ip: ${ip}"

	VOLUME_DIR=${VOLUMES_DIR}/volume1/${ip}
	KEY_DIR=${KEYS_DIR}/${ip}

	mkdir -p ${VOLUME_DIR} ${KEY_DIR}
	WORKING_DIR=${VOLUME_DIR}

	password=$(pwgen -c 25 -n 1)
	PASSWORD_FILE=${WORKING_DIR}/nodekey_password
	echo $password > $PASSWORD_FILE

	# Setup node wallet
	geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
	nodekey_ks=${WORKING_DIR}/nodekey_keystore
	mv ${WORKING_DIR}/UTC* ${nodekey_ks}

	CONTENT_FILE=${WORKING_DIR}/nodekey_contents
	ethkey inspect --private --passwordfile $PASSWORD_FILE $nodekey_ks > ${CONTENT_FILE}

	# move contents to the key directory
	sed  -n "s/Private\skey:\s*\(.*\)/\1/p"  ${CONTENT_FILE} | tr -d '\n' > ${KEY_DIR}/nodekey
	sed  -n "s/Public\skey:\s*04\(.*\)/\1/p" ${CONTENT_FILE} | tr -d '\n' > ${KEY_DIR}/nodekey_pub
	sed  -n "s/Address:\s*\(.*\)/\1/p"       ${CONTENT_FILE} | tr -d '\n' > ${KEY_DIR}/nodekey_address
	rm ${CONTENT_FILE}

	# Setup account wallet
	password2=$(pwgen -c 25 -n 1)
	geth account new --password <(echo -n "$password2") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
	mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/account_keystore
	echo $password2 > ${WORKING_DIR}/account_password

	echo -n "0x$(cat ${WORKING_DIR}/account_keystore | jq -r ".address" | tr -d '\n')" > ${KEY_DIR}/account_address
done
