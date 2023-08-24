#!/usr/bin/env zsh

set -e

# ############################################################
#	----------------- Key Generation
# ############################################################

# SCRIPTS_DIR=$(dirname ${(%):-%N})
# BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
# LOG_FILE=${BASE_DIR}/ceremony.log
# ENV_FILE=${BASE_DIR}/.env
# VOLUMES_DIR=${BASE_DIR}/volumes
# ADMIN_KEY_BATCH_SIZE=5
# ADMIN_KEYS=100

usage() {
	echo "Options"
	echo "  -a : How many admin lockup admin keys will be created"
	echo "  -b : Batch size for async key creations"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
	echo "  -i : List of IP addresses"
	echo "  -l : Path to log file"
	echo "  -v : Path where all keys will be generated"
}

while getopts a:b:hi:v: option; do
	case "${option}" in
		a)
			ADMIN_KEYS=${OPTARG}
			;;
		b)
			ADMIN_KEY_BATCH_SIZE=${OPTARG}
			;;
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

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${VOLUMES_DIR}" ]] && echo ".env is missing VOLUMES_DIR variable" && exit 1
[[ ! -d "${VOLUMES_DIR}" ]] && echo "VOLUMES_DIR environment variable is not a directory. Expecting it here ${VOLUMES_DIR}" && exit 1

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
	file_exists "${SCRIPTS_DIR}/printer.sh"
	${SCRIPTS_DIR}/printer.sh "$@" | tee -a ${LOG_FILE}
}

generate_wallet() {
	file_exists "${SCRIPTS_DIR}/generate_wallet.sh"
	${SCRIPTS_DIR}/generate_wallet.sh "$@" &>> ${LOG_FILE}
}

lockup_admin_wallets() {
	[[ -z "${ADMIN_KEYS}" ]] && echo ".env is missing ADMIN_KEYS variable" && exit 1

	vol1=${VOLUMES_DIR}/volume1/lockupAdmins
	vol2=${VOLUMES_DIR}/volume2/lockupAdmins

	for i in {1..$ADMIN_KEYS}; do
		generate_wallet -o "${vol1} ${vol2}" -a &
		if (( $i % $ADMIN_KEY_BATCH_SIZE == 0 )); then
			wait
			printer -n "Created ${i} lockup admin wallets"
		fi
	done
	printer -n "Created ${ADMIN_KEYS} lockup admin wallets in total"
	wait

	printer -n "Created lockup admin wallets"
}

lockup_owner_wallets() {
	vol1=${VOLUMES_DIR}/volume1/lockupOwner
	vol3=${VOLUMES_DIR}/volume3/lockupOwner

	generate_wallet -o "${vol1} ${vol3}"

	printer -n "Created lockup owner wallets"
}

distribution_owner_wallets() {
	printer
	vol1=${VOLUMES_DIR}/volume1/distributionOwner
	vol3=${VOLUMES_DIR}/volume3/distributionOwner
	vol4=${VOLUMES_DIR}/volume4/distributionOwner

	generate_wallet -o "${vol1} ${vol3} ${vol4}"

	printer -n "Created distribution owner wallets"
}

distribution_issuer_wallets() {
	vol1=${VOLUMES_DIR}/volume1/distributionIssuer
	vol2=${VOLUMES_DIR}/volume2/distributionIssuer

	generate_wallet -o "${vol1} ${vol2}"

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

bridge_wallets() {
	${SCRIPTS_DIR}/create_bridge_wallets.sh &>> ${LOG_FILE}
}

[ -z "${VALIDATOR_IPS}" ] && printer -e "No vaildator IPs"

printer -t "Creating ceremony keys"

lockup_admin_wallets

lockup_owner_wallets &
distribution_owner_wallets &
distribution_issuer_wallets &
bridge_wallets &
wait

validator_account_wallets "$VALIDATOR_IPS"

printer -s "Key creation complete"

