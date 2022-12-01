#!/bin/bash

${SCRIPTS_DIR}/print_title.sh "Executing Ansible Playbook"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

ansible-playbook -i ${INVENTORY_PATH} ${ANSIBLE_DIR}/goquorum.yaml --private-key=${SSH_KEY_DOWNLOAD_PATH}

