#!/usr/bin/env bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

ansible-galaxy install git+https://${GITHUB_SYSOPS_TOKEN}:@github.com/NerdUnited-Nerd/ansible-role-lace,${ANSIBLE_ROLE_LACE_VERSION} --force
