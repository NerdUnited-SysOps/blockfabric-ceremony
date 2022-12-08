#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../../.common.sh

VOL=${VOLUMES_DIR}/volume1/lockupAdmins

addresses=$(ls $VOL)

npm --prefix ${SCRIPT_DIR}/package.json i &>> ${LOG_FILE}

node ${SCRIPTS_DIR}/create_lockup_storage/createStorage.js $addresses

