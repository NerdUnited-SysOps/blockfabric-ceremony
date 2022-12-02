#!/usr/bin/env bash

${SCRIPTS_DIR}/printer.sh -t "Installing Ansible role"

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

ansible-galaxy install git+https://${GITHUB_SYSOPS_TOKEN}:@github.com/NerdUnited-Nerd/ansible-role-lace,${ANSIBLE_ROLE_LACE_VERSION} --force

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to install ansible role"
fi

