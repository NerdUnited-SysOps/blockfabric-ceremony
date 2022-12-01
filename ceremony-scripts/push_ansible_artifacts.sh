#!/bin/bash

${SCRIPTS_DIR}/print_title.sh "Pushing Ansible artifacts"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

BRAND=${1:-nerd}
NETWORK=${2:-mainnet}

REPO_NAME=ansible.${BRAND}-${NETWORK}
WORKING_DIR=${BASE_DIR}/../${REPO_NAME}
BRAND_ANSIBLE_URL=https://${GITHUB_SYSOPS_TOKEN}:@github.com/NerdUnited-SysOps/${REPO_NAME}.git

mkdir -p ${ANSIBLE_DIR}

cp -r  ${ANSIBLE_DIR}/* ${WORKING_DIR}

if [ ! $? -eq 0 ]; then
   echo "Failed to copy ansible content to brand repo"
   exit 1
fi


git -C ${WORKING_DIR}/ checkout -b ceremony-artifacts
git -C ${WORKING_DIR}/ add ${WORKING_DIR}
git -C ${WORKING_DIR}/ commit -m "Committing produced artifacts"
git -C ${WORKING_DIR}/ push origin HEAD

