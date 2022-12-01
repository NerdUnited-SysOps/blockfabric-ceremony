#!/bin/bash

${SCRIPTS_DIR}/print_title.sh "Fetching ansible variables"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

BRAND=${1:-nerd}
NETWORK=${2:-mainnet}

REPO_NAME=ansible.${BRAND}-${NETWORK}
WORKING_DIR=${BASE_DIR}/../${REPO_NAME}
BRAND_ANSIBLE_URL=https://${GITHUB_SYSOPS_TOKEN}:@github.com/NerdUnited-SysOps/${REPO_NAME}.git

rm -rf ${WORKING_DIR}

git clone ${BRAND_ANSIBLE_URL} ${WORKING_DIR}

if [ ! $? -eq 0 ]; then
   echo "Failed to clone brand repo ${BRAND_ANSIBLE_URL}"
   exit 1
fi

mkdir -p ${ANSIBLE_DIR}

cp ${WORKING_DIR}/brand_vars.yaml ${ANSIBLE_DIR}/brand_vars.yaml

