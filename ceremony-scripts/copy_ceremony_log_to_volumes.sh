#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Moving ceremony_log file to all volumes"

cp $LOG_FILE ${VOLUMES_DIR}/volume1
cp $LOG_FILE ${VOLUMES_DIR}/volume2
cp $LOG_FILE ${VOLUMES_DIR}/volume3
cp $LOG_FILE ${VOLUMES_DIR}/volume4

${SCRIPTS_DIR}/printer.sh -t "Successfully moved ceremony_log file to all volumes"