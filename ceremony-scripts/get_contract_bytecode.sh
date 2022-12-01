#!/bin/bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

DAO_DIR=${CONTRACTS_DIR}/sc_dao/${DAO_VERSION}
DAO_ASSET_VERSION=86410959
DAO_URL=https://${GITHUB_CORESDK_TOKEN}:@api.github.com/repos/NerdCoreSdk/sc_dao/releases/assets/${DAO_ASSET_VERSION}

LOCKUP_DIR=${CONTRACTS_DIR}/sc_lockup/${LOCKUP_VERSION}
LOCKUP_ASSET_VERSION=86414347
LOCKUP_URL=https://${GITHUB_CORESDK_TOKEN}:@api.github.com/repos/NerdCoreSdk/sc_lockup/releases/assets/${LOCKUP_ASSET_VERSION}

# Find the assets in a release
# curl -H "Accept: application/vnd.github+json" -H 'Authorization: Bearer ${GITHUB_CORESDK_TOKEN}' 'https://api.github.com/repos/NerdCoreSdk/sc_lockup/releases'

# The expected path will be the following
# $CONTRACTS_DIR/
#   /sc_dao
#     /v0.0.1
#       /*.bin-runtime
#   /sc_lockup
#     /v0.1.0
#       /*.bin

echo "Downloading smart contract bytecode" | tee ${LOG_FILE}

mkdir -p ${DAO_DIR} ${LOCKUP_DIR}

wget -q --auth-no-challenge \
	--header='Accept:application/octet-stream' \
	${LOCKUP_URL} -O ${LOCKUP_DIR}/lockup.tar.gz &>> ${LOG_FILE}

if [ ! $? -eq 0 ]; then
   echo "Failed to retrieve lockup code"
   exit 1
fi

tar -xvf ${LOCKUP_DIR}/lockup.tar.gz -C ${LOCKUP_DIR} &>> ${LOG_FILE}

wget -q --auth-no-challenge \
	--header='Accept:application/octet-stream' \
	${DAO_URL} -O ${DAO_DIR}/dao.zip &>> ${LOG_FILE}

if [ ! $? -eq 0 ]; then
   echo "Failed to retrieve dao code"
   exit 1
fi

unzip -o ${DAO_DIR}/dao.zip -d ${DAO_DIR} &>> ${LOG_FILE}

