#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Generating lockup owner wallet"

VOL1=${VOLUMES_DIR}/volume1/lockupOwner
VOL3=${VOLUMES_DIR}/volume3/lockupOwner
KEY_DIR=${KEYS_DIR}/lockupOwner

mkdir -p ${VOL1} ${VOL3} ${KEY_DIR}
WORKING_DIR=${VOL1}

password=$(pwgen -c 25 -n 1)

geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/keystore
echo $password > ${WORKING_DIR}/password

cp ${WORKING_DIR}/keystore ${VOL3}/keystore
echo $password > ${VOL3}/password

address=$(cat ${WORKING_DIR}/keystore | jq -r ".address" | tr -d '\n')
echo $address > ${KEY_DIR}/address

${SCRIPTS_DIR}/printer.sh -s "Generated lockup owner wallet"

