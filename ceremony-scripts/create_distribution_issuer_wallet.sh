#!/bin/bash

echo "Generating distribution issuer wallet"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

vol1=${VOLUMES_DIR}/volume1/distributionIssuer
vol2=${VOLUMES_DIR}/volume2/distributionIssuer

mkdir -p ${vol1} ${vol2}
WORKING_DIR=${vol1}

password=$(pwgen -c 25 -n 1)

geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/keystore
echo $password > ${WORKING_DIR}/password

cp ${WORKING_DIR}/keystore ${vol2}/keystore
echo $password > ${vol2}/password
