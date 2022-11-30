#!/bin/bash

echo "Generating lockup owner wallet"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

vol1=${VOLUMES_DIR}/volume1/lockupOwner
vol3=${VOLUMES_DIR}/volume3/lockupOwner
key_dir=${KEYS_DIR}/lockupOwner

mkdir -p ${vol1} ${vol3} ${key_dir}
WORKING_DIR=${vol1}

password=$(pwgen -c 25 -n 1)

geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/keystore
echo $password > ${WORKING_DIR}/password

cp ${WORKING_DIR}/keystore ${vol3}/keystore
echo $password > ${vol3}/password

address=$(cat ${WORKING_DIR}/keystore | jq -r ".address" | tr -d '\n')
echo $address > ${key_dir}/address
