#!/usr/bin/env zsh

set -e

# ############################################################
#	----------------- Key Generation
# ############################################################

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
	echo "  -i : List of IP addresses"
}

while getopts hi:v:e: option; do
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

[[ -z "${VOLUMES_DIR}" ]] && echo ".env is missing VOLUMES_DIR variable" && exit 1

[[ -z "${LOG_FILE}" ]] && echo ".env is missing LOG_FILE variable" && exit 1
[[ ! -f "${LOG_FILE}" ]] && echo "LOG_FILE environment variable is not a file. Expecting it here ${LOG_FILE}" && exit 1

file_exists() {
	file_path=$1
	if [ ! -f "${file_path}" ]; then
		echo "Cannot find ${file_path}"
		exit 1
	fi
}

printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} file doesn't exist" && exit 1
	${SCRIPTS_DIR}/printer.sh "$@" | tee -a ${LOG_FILE}
}

generate_wallet() {
	[[ ! -f "${SCRIPTS_DIR}/generate_wallet.sh" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} file doesn't exist" && exit 1
	${SCRIPTS_DIR}/generate_wallet.sh -e "${ENV_FILE}" "$@" &>> ${LOG_FILE}
}

safe_owner_wallets() {
	for i in {1..${SAFE_OWNER_COUNT:-3}}; do
		generate_wallet -o "${VOLUMES_DIR}/volume${i}/lockupOwner${i}" &
	done
	wait

	printer -n "Created ${SAFE_OWNER_COUNT:-3} Safe owner wallets"
}

distribution_issuer_wallets() {
	generate_wallet -o "${VOLUMES_DIR}/volume2/distributionIssuer"

	printer -n "Created distribution issuer wallets"
}


validator_account_wallet() {
	ip=$1

	account=${VOLUMES_DIR}/volume1/${ip}/account
	generate_wallet -o "${account}"

	node=${VOLUMES_DIR}/volume1/${ip}/node
	generate_wallet -o "${node}"
}

validator_account_wallets() {
	IP_ADDRESS_LIST=$1

	# Create an array from a space-delimited string
	ips=(${(@s: :)IP_ADDRESS_LIST})

	for ip in ${ips}; do
		validator_account_wallet $ip &
	done
	wait

	printer -n "Created validator and account wallets"
}

[ -z "${VALIDATOR_IPS}" ] && printer -e "No vaildator IPs"

printer -t "Creating ceremony keys"

safe_owner_wallets &
distribution_issuer_wallets &
wait

validator_account_wallets "$VALIDATOR_IPS"

printer -s "Key creation complete"

