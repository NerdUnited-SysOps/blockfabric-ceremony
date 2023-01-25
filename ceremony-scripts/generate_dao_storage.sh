#!/usr/bin/env zsh

set -e

# Directory of this file
SCRIPTS_DIR=$(dirname ${(%):-%N})
ENV_FILE="${SCRIPTS_DIR}/../.env"

BASE_DIR=${SCRIPTS_DIR}/..
CONTRACTS_DIR=${BASE_DIR}/contracts
UTIL_SCRIPTS_DIR=${SCRIPTS_DIR}/util
VOLUMES_DIR=${SCRIPTS_DIR}/../volumes

usage() {
  echo "Usage: $0 (options) ..."
  echo "  -f : Path to .env file"
  echo "  -h : Help"
  echo "  -i : List of IP addresses"
	echo "  -l : Path to log file"
  echo ""
  echo "Example: "
}

while getopts 'f:hi:l:' option; do
	case "$option" in
		f)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		i)
			IP_ADDRESS_LIST=${OPTARG}
			;;
		l)
			LOG_FILE=${OPTARG}
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

[ -z "${IP_ADDRESS_LIST}" ] && printer -e "No vaildator IPs"

printer -t "Generating the Validator DAO Storage"

DAO_DIR=${CONTRACTS_DIR}/sc_dao/${DAO_VERSION}
mkdir -p ${DAO_DIR}

curl -L -H "Authorization: Bearer ${GITHUB_PAT}" ${GITHUB_DAO_URL} --output ${DAO_DIR}/repo.zip &>> ${LOG_FILE}

if [ $? -eq 0 ]; then
	printer -n "Retrieved Validator DAO code"
else
	printer -e "Failed retrieve Validator DAO code"
fi

rm -rf ${DAO_DIR}/repo
unzip -o ${DAO_DIR}/repo.zip -d ${DAO_DIR} &>> ${LOG_FILE}

if [ $? -eq 0 ]; then
	printer -n "Unpacked DAO code"
else
	printer -e "Failed to unpack DAO code"
fi

mv ${DAO_DIR}/Nerd* ${DAO_DIR}/repo

WORKING_DIR=${DAO_DIR}/repo/genesisContent

# Create the allowList
ALLOWED_ACCOUNTS_FILE=${WORKING_DIR}/allowedAccountsAndValidators.txt


echo -n > $ALLOWED_ACCOUNTS_FILE

get_address() {
	key_file=$1

	grep -o '"address": *"[^"]*"' "${key_file}" | grep -o '"[^"]*"$' | sed 's/"//g'
}

ips=(${(@s: :)IP_ADDRESS_LIST})
for ip in ${ips}
do
	IP_DIR=${VOLUMES_DIR}/volume1/${ip}
	ACCOUNT_ADDRESS=$(get_address ${IP_DIR}/account/keystore)
	NODEKEY_ADDRESS=$(get_address ${IP_DIR}/node/keystore)
	echo "0x$ACCOUNT_ADDRESS, 0x$NODEKEY_ADDRESS" >> $ALLOWED_ACCOUNTS_FILE
done

cd $WORKING_DIR
npm i &>> ${LOG_FILE}
node ./createContent.js
cd -
mv ${WORKING_DIR}/Storage.txt ${DAO_DIR}

printer -s "Completed storage generation"

