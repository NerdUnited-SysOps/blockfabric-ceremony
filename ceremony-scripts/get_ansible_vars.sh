#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Fetching ansible variables"

BRAND=${1:-nerd}
NETWORK=${2:-mainnet}
GITHUB_ORG_URL=${3:-github.com/NerdUnited-SysOps}

REPO_NAME=ansible.${BRAND}-${NETWORK}
WORKING_DIR=${BASE_DIR}/../${REPO_NAME}
BRAND_ANSIBLE_URL=https://${GITHUB_SYSOPS_TOKEN}:@${GITHUB_ORG_URL}/${REPO_NAME}.git

rm -rf ${WORKING_DIR}

git clone ${BRAND_ANSIBLE_URL} ${WORKING_DIR}

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to clone brand repo ${BRAND_ANSIBLE_URL}"
fi

mkdir -p ${ANSIBLE_DIR}

cp ${WORKING_DIR}/brand_vars.yaml ${ANSIBLE_DIR}/brand_vars.yaml

