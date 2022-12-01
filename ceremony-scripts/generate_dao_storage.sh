#!/bin/bash

IP_ADDRESS_LIST=${1:?ERROR: Missing IP Address list}

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $BASE_DIR/../.common.sh

${SCRIPTS_DIR}/print_title.sh "Generating the Validator DAO Storage"

DAO_DIR=${CONTRACTS_DIR}/sc_dao/${DAO_VERSION}
DAO_URL=https://api.github.com/repos/NerdCoreSdk/sc_dao/zipball/${DAO_VERSION}
mkdir -p ${DAO_DIR}

curl -L -H "Authorization: Bearer ${GITHUB_CORESDK_TOKEN}" ${DAO_URL} --output ${DAO_DIR}/repo.zip &>> ${LOG_FILE}

rm -rf ${DAO_DIR}/repo
unzip -o ${DAO_DIR}/repo.zip -d ${DAO_DIR} &>> ${LOG_FILE}
mv ${DAO_DIR}/Nerd* ${DAO_DIR}/repo

WORKING_DIR=${DAO_DIR}/repo/genesisContent
cd $WORKING_DIR

# Create the allowList

ALLOWED_ACCOUNTS_FILE=${WORKING_DIR}/allowedAccountsAndValidators.txt
echo -n > $ALLOWED_ACCOUNTS_FILE
for ip in ${IP_ADDRESS_LIST}
do
  IP_DIR=${KEYS_DIR}/${ip}
  ACCOUNT_ADDRESS=$(cat ${IP_DIR}/account_address | tr -d '\n')
  NODEKEY_ADDRESS=$(cat ${IP_DIR}/nodekey_address | tr -d '\n')
  echo "$ACCOUNT_ADDRESS, $NODEKEY_ADDRESS" >> $ALLOWED_ACCOUNTS_FILE
done

npm i &>> ${LOG_FILE}
node ./createContent.js
mv ${WORKING_DIR}/Storage.txt ${DAO_DIR}

cd $BASE_DIR

${SCRIPTS_DIR}/print_success.sh "Completed storage generation"

