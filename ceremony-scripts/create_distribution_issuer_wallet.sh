#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Generating distribution issuer wallet"

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

PRIVATE_KEY=$(ethkey inspect --private --passwordfile ${WORKING_DIR}/password ${WORKING_DIR}/keystore | grep Private | sed 's/Private key\:\s*//')

aws secretsmanager \
	put-secret-value \
	--secret-id ${AWS_DISTIRBUTION_ISSUER_KEY_NAME} \
	--secret-string ${PRIVATE_KEY} &>> ${LOG_FILE}

if [ $? -eq 0 ]; then
	${SCRIPTS_DIR}/printer.sh -s "Generated distribution wallet"
else
	aws secretsmanager \
		create-secret \
		--name ${AWS_DISTIRBUTION_ISSUER_KEY_NAME} \
		--secret-string ${PRIVATE_KEY}

	if [ $? -eq 0 ]; then
		${SCRIPTS_DIR}/printer.sh -s "Generated distribution issuer wallet"
	else
		${SCRIPTS_DIR}/printer.sh -e "Failed to push distribution wallet to secret manager"
	fi
fi

