#!/usr/bin/zsh

set -e

# ############################################################
#	----------------- Bridge Key Generation
# ############################################################

SCRIPTS_DIR=$(dirname ${(%):-%N})
BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
LOG_FILE=${BASE_DIR}/ceremony.log
ENV_FILE=${BASE_DIR}/.env
VOLUMES_DIR=${BASE_DIR}/volumes
ADMIN_KEY_BATCH_SIZE=5
ADMIN_KEYS=100

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
	echo "  -l : Path to log file"
	echo "  -v : Path where all keys will be generated"
}

while getopts a:b:hi:v: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		l)
			LOG_FILE=${OPTARG}
			;;
		v)
			VOLUMES_DIR=${OPTARG}
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

printer() {
	${SCRIPTS_DIR}/printer.sh "$@" | tee -a ${LOG_FILE}
}

generate_wallet() {
	${SCRIPTS_DIR}/generate_wallet.sh "$@" &>> ${LOG_FILE}
}

bridge_approver_wallet() {
	vol5=${VOLUMES_DIR}/volume5/bridge_approver

	generate_wallet -o "${vol5}"

	printer -s "Created approver wallet"
}

bridge_notary_wallet() {
	vol5=${VOLUMES_DIR}/volume5/bridge_notary

	generate_wallet -o "${vol5}"

	printer -s "Created notary wallet"
}

bridge_fee_receiver_wallet() {
    vol5=${VOLUMES_DIR}/volume5/bridge_fee_receiver

	generate_wallet -o "${vol5}"

	printer -s "Created fee receiver wallet"
}

bridge_minter_approver_wallet() {
    vol5=${VOLUMES_DIR}/volume5/bridge_minter_approver

	generate_wallet -o "${vol5}"

	printer -s "Created approver wallet"
}

bridge_minter_notary_wallet() {
    vol5=${VOLUMES_DIR}/volume5/bridge_minter_notary

	generate_wallet -o "${vol5}"

	printer -s "Created notary wallet"
}

token_owner_wallet() {
    vol5=${VOLUMES_DIR}/volume5/token_owner

	generate_wallet -o "${vol5}"

	printer -s "Created fee receiver wallet"
}

bridge_wallets() {
    bridge_approver_wallet
    bridge_notary_wallet
    bridge_fee_receiver_wallet

    printer -s "Created bridge wallets"
}

bridge_minter_wallets() {
    bridge_minter_approver_wallet
    bridge_minter_notary_wallet
    printer -s "Created bridge minter wallets"
}

token_wallets() {
    token_owner_wallet
    printer -s "Created token wallet(s)"
}


bridge_wallets &
bridge_minter_wallets &
token_wallets &
wait


printer -s "Bridge key creation complete"


# EOF
