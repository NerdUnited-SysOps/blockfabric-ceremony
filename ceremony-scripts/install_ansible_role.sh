#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Installing Ansible role"

ansible-galaxy install git+https://${GITHUB_SYSOPS_TOKEN}:@${ANSIBLE_INSTALL_URL} --force

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to install ansible role"
fi

