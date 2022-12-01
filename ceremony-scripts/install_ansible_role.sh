#!/usr/bin/env bash

${SCRIPTS_DIR}/print_title.sh "Installing Ansible role"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

ansible-galaxy install git+https://${GIT_TOKEN}:@github.com/NerdUnited-Nerd/ansible-role-lace,${ANSIBLE_ROLE_LACE_VERSION} --force

