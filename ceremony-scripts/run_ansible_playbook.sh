#!/bin/bash

${SCRIPTS_DIR}/printer.sh -t "Executing Ansible Playbook"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

ansible-playbook -i ${INVENTORY_PATH} ${ANSIBLE_DIR}/goquorum.yaml --private-key=${AWS_NODES_SSH_KEY_PATH}

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to execute ansible playbook"
fi

