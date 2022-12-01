#!/bin/bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

rm -r ${KEYS_DIR} \
    ${CONTRACTS_DIR} \
    ${VOLUMES_DIR} \
    ${ANSIBLE_DIR} \
    ${LOG_FILE} \
		${AWS_CONDUCTOR_SSH_KEY_PATH} \
		${AWS_NODES_SSH_KEY_PATH}

ansible-galaxy remove ansible-role-lace
