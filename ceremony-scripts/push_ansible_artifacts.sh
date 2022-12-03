#!/bin/bash


SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${BASE_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Pushing Ansible artifacts"

BRAND=${1:-nerd}
NETWORK=${2:-mainnet}
GITHUB_ORG_URL=${3:-github.com/NerdUnited-SysOps}

REPO_NAME=ansible.${BRAND}-${NETWORK}
WORKING_DIR=${BASE_DIR}/../${REPO_NAME}
BRAND_ANSIBLE_URL=https://${GITHUB_SYSOPS_TOKEN}:@${GITHUB_ORG_URL}/${REPO_NAME}.git

mkdir -p ${ANSIBLE_DIR}

cp -r  ${ANSIBLE_DIR}/* ${WORKING_DIR}

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to copy ansible content to brand repo"
fi

git -C ${WORKING_DIR}/ checkout -b ceremony-artifacts
git -C ${WORKING_DIR}/ add ${WORKING_DIR}
git -C ${WORKING_DIR}/ commit -m "Committing produced artifacts"
git -C ${WORKING_DIR}/ push origin HEAD --force &>> ${LOG_FILE}

${SCRIPTS_DIR}/printer.sh -s "Pushed ansible code to remote repo"

