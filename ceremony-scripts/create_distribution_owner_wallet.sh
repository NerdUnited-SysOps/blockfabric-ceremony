#!/bin/bash

${SCRIPTS_DIR}/print_title.sh "Generating distribution owner wallet"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

VOL1=${VOLUMES_DIR}/volume1/distributionOwner
VOL3=${VOLUMES_DIR}/volume3/distributionOwner
VOL4=${VOLUMES_DIR}/volume4/distributionOwner
KEY_DIR=${KEYS_DIR}/distributionOwner

mkdir -p ${VOL1} ${VOL3} ${VOL4} ${KEY_DIR}
WORKING_DIR=${VOL1}

password=$(pwgen -c 25 -n 1)

geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/keystore
echo $password > ${WORKING_DIR}/password

cp ${WORKING_DIR}/keystore ${VOL3}/keystore
echo $password > ${VOL3}/password

cp ${WORKING_DIR}/keystore ${VOL4}/keystore
echo $password > ${VOL4}/password

address=$(cat ${WORKING_DIR}/keystore | jq -r ".address" | tr -d '\n')
echo $address > ${KEY_DIR}/address

