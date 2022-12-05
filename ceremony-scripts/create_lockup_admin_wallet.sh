#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Generating lockup admin wallet"

VOL1=${VOLUMES_DIR}/volume1/distributionIssuer
VOL2=${VOLUMES_DIR}/volume2/distributionIssuer

mkdir -p ${VOL1} ${VOL2}
WORKING_DIR=${VOL1}

password=$(pwgen -c 25 -n 1)

geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
mv ${WORKING_DIR}/UTC* ${WORKING_DIR}/keystore
echo $password > ${WORKING_DIR}/password

cp ${WORKING_DIR}/keystore ${VOL2}/keystore
echo $password > ${VOL2}/password

${SCRIPTS_DIR}/printer.sh -s "Generated lockup admin wallet"

