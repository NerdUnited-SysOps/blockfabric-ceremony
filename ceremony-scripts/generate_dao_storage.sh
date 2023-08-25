#!/usr/bin/env zsh

set -e

usage() {
  echo "Usage: $0 (options) ..."
  echo "  -e : Path to .env file"
  echo "  -h : Help"
  echo "  -i : List of IP addresses"
  echo ""
  echo "Example: "
}

while getopts 'e:hi:l:' option; do
	case "$option" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		i)
			IP_ADDRESS_LIST=${OPTARG}
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${CONTRACTS_DIR}" ]] && echo ".env is missing CONTRACTS_DIR variable" && exit 1

[[ -z "${VOLUMES_DIR}" ]] && echo ".env is missing VOLUMES_DIR variable" && exit 1
[[ ! -d "${VOLUMES_DIR}" ]] && echo "VOLUMES_DIR environment variable is not a directory. Expecting it here ${VOLUMES_DIR}" && exit 1


printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} ${SCRIPTS_DIR}/printer.sh file doesn't exist" && exit 1
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

