#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Environment config file"
	echo "  -h : This help message"
}

while getopts he: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${RPC_PORT}" ]] && echo "${0}:${LINENO} .env is missing RPC_PORT variable" && exit 1
[[ -z "${RPC_PATH}" ]] && echo "${0}:${LINENO} .env is missing RPC_PATH variable" && exit 1

VALIDATION_DIR=$(dirname ${(%):-%N})

${VALIDATION_DIR}/validate_chain_besu.sh \
  -i $INVENTORY_PATH \
  -p $RPC_PORT \
  -r $RPC_PATH \
  -v ${VALIDATION_DIR}/remoteValidate_besu.sh
