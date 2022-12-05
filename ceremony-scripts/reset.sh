#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

rm -rf ${KEYS_DIR} \
    ${CONTRACTS_DIR} \
    ${VOLUMES_DIR} \
    ${ANSIBLE_DIR} \
    ${LOG_FILE} \
		${AWS_CONDUCTOR_SSH_KEY_PATH} \
		${AWS_NODES_SSH_KEY_PATH}

ansible-galaxy remove ansible-role-lace
# For a full reset, including the nodes
# ansible-playbook --limit all_quorum -i ~/ansible/inventory --private-key=~/blockfabric-ceremony/id_rsa_nodes ~/ansible/reset.yaml
