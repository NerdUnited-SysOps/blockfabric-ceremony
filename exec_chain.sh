#!/usr/bin/zsh

set -e

ENV_FILE=./.env
source ${ENV_FILE}

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

