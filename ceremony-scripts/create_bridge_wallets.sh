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
	echo "  -i : List of IP addresses"
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
		i)
			VALIDATOR_IPS=${OPTARG}
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
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_approver

	generate_wallet -o "${vol5}"

	printer -n "Created approver wallet"
}

bridge_notary_wallet() {
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_notary

	generate_wallet -o "${vol5}"

	printer -n "Created notary wallet"
}

bridge_fee_receiver_wallet() {
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_fee_receiver

	generate_wallet -o "${vol5}"

	printer -n "Created fee receiver wallet"
}

bridge_minter_approver_wallet() {
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_minter_approver

	generate_wallet -o "${vol5}"

	printer -n "Created approver wallet"
}

bridge_minter_notary_wallet() {
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_minter_notary

	generate_wallet -o "${vol5}"

	printer -n "Created notary wallet"
}

token_owner_wallet() {
    vol=5
	vol${vol}=${VOLUMES_DIR}/volume${vol}/token_owner

	generate_wallet -o "${vol5}"

	printer -n "Created fee receiver wallet"
}

bridge_wallets() {
    printer -t "Creating bridge wallets"

    bridge_owner_wallet
    bridge_approver_wallet
    bridge_notary_wallet
    bridge_fee_receiver_wallet
}

bridge_minter_wallets() {
    printer -t "Creating bridge wallets"

    bridge_minter_approver_wallet
    bridge_minter_notary_wallet
}

token_wallets() {
    printer -t "Creating token wallet(s)"

    token_owner_wallet
}

printer -t "Creating bridge ceremony keys"

bridge_wallets &
bridge_minter_wallets &
token_wallets &
wait

printer -s "Bridge key creation complete"


# EOF
