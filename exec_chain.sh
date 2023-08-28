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

shift "$(( OPTIND - 1 ))"

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${NODE_USER}" ]] && echo "${0}:${LINENO} .env is missing NODE_USER variable" && exit 1
[[ -z "${RPC_PATH}" ]] && echo "${0}:${LINENO} .env is missing RPC_PATH variable" && exit 1
[[ -z "${REMOTE_GETH_PATH}" ]] && echo "${0}:${LINENO} .env is missing REMOTE_GETH_PATH variable" && exit 1
[[ -z "${DATADIR}" ]] && echo "${0}:${LINENO} .env is missing DATADIR variable" && exit 1

exec_chain() {
	exec_cmd=$1

	ssh \
		-q \
		-o LogLevel=quiet \
		-o ConnectTimeout=10 \
		-o StrictHostKeyChecking=no \
		-i ${AWS_NODES_SSH_KEY_PATH} \
		"${NODE_USER}@${RPC_PATH}" "sudo ${REMOTE_GETH_PATH} attach \
			--datadir ${DATADIR} \
			--exec \"${exec_cmd}\""
}

exec_chain "$@"

