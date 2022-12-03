#!/usr/bin/env bash

${SCRIPTS_DIR}/printer.sh -t "Installing Ansible role"

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

GITHUB_ORG_URL=${1:-github.com/NerdUnited-Nerd}
REPO_NAME=${2:-ansible-role-lace}

REPO_NAME=ansible.${BRAND}-${NETWORK}

ansible-galaxy install git+https://${GITHUB_SYSOPS_TOKEN}:@${GITHUB_ORG_URL}/${REPO_NAME},${ANSIBLE_ROLE_LACE_VERSION} --force

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to install ansible role"
fi

