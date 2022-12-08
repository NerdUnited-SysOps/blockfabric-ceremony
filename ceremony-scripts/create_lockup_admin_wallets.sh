#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Generating lockup admin wallets"

VOL1=${VOLUMES_DIR}/volume1/lockupAdmins
VOL2=${VOLUMES_DIR}/volume2/lockupAdmins

mkdir -p ${VOL1} ${VOL2}
WORKING_DIR=${VOL1}

create_key() {
    password=$(pwgen -c 25 -n 1)
    echo $password > ${WORKING_DIR}/password

    geth account new --password <(echo -n "$password") --keystore ${WORKING_DIR} &>> ${LOG_FILE}
    
    PRIVATE_KEY=$(ethkey inspect --private --passwordfile ${WORKING_DIR}/password ${WORKING_DIR}/UTC* | grep Private | sed 's/Private key\:\s*//')
    address=$(cat ${WORKING_DIR}/UTC* | jq -r ".address" | tr -d '\n')
    echo $PRIVATE_KEY > $WORKING_DIR/$address
    cp $WORKING_DIR/$address $VOL2

    rm $WORKING_DIR/UTC*
    rm $WORKING_DIR/password

    if (( $i % 10 == 0 ))
    then
        ${SCRIPTS_DIR}/printer.sh -n "Generated ${i} lockup admin wallets so far"
    fi
}

# for i in {1..100}
for i in {1..10}
				create_key &
do
done
wait

${SCRIPTS_DIR}/printer.sh -s "Generated lockup admin wallets"

