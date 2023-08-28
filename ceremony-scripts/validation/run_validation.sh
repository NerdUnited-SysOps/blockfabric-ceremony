#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
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

[[ -z "${DATADIR}" ]] && echo "${0}:${LINENO} .env is missing DATADIR variable" && exit 1
[[ -z "${REMOTE_GETH_PATH}" ]] && echo "${0}:${LINENO} .env is missing REMOTE_GETH_PATH variable" && exit 1
[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${RPC_PORT}" ]] && echo "${0}:${LINENO} .env is missing RPC_PORT variable" && exit 1
[[ -z "${RPC_PATH}" ]] && echo "${0}:${LINENO} .env is missing RPC_PATH variable" && exit 1
[[ -z "${NODE_USER}" ]] && echo "${0}:${LINENO} .env is missing NODE_USER variable" && exit 1
[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1

VALIDATION_DIR=$(dirname ${(%):-%N})

SSH_HOST=$(dig +short $RPC_PATH | head -1)

${VALIDATION_DIR}/validate_chain.sh \
  -d $DATADIR \
  -g $REMOTE_GETH_PATH \
  -i $INVENTORY_PATH \
  -k $AWS_NODES_SSH_KEY_PATH \
  -p $RPC_PORT \
  -r $RPC_PATH \
  -u $NODE_USER \
  -v ${VALIDATION_DIR}/remoteValidate.js \
  -x ${SSH_HOST}

