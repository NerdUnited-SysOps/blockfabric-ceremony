#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../../.common.sh

VOL=${VOLUMES_DIR}/volume1/lockupAdmins

addresses=$(ls $VOL)

cd ${SCRIPT_DIR} > /dev/null

npm i &>> ${LOG_FILE}

node ${SCRIPT_DIR}/createStorage.js $addresses

cd - > /dev/null

