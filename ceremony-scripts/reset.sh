#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

HARD_RESET="false"

usage() {
  echo "This script resets the ceremony"
  echo "Usage: $0 (options) ..."
  echo "  -x : hard reset - if possible, reset nodes"
  echo "  -h : Help"
  echo ""
  echo "Example: reset.sh -x"
}

while getopts 'hx' option; do
	case "$option" in
		x)
			HARD_RESET="true"
			;;
		h)
			usage
			exit 0
			;;
	esac
done
shift $((OPTIND-1))

# For a full reset, including the nodes
if [ ${HARD_RESET} == "true" ]; then
	ansible-playbook --limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/reset.yaml
fi

rm -rf ${KEYS_DIR} \
	${CONTRACTS_DIR} \
	${VOLUMES_DIR} \
	${ANSIBLE_DIR} \
	${LOG_FILE} \
	${AWS_CONDUCTOR_SSH_KEY_PATH} \
	${AWS_NODES_SSH_KEY_PATH} \
	${ANSIBLE_ROLE_INSTALL_PATH}

# git push origin --delete ceremony-artifacts
