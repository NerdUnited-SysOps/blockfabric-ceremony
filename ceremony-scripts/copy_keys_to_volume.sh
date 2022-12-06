#!/bin/bash

EXTERNAL_VOLUME_PATH=$1 # Example - /dev/sdc1
VOLUME_CONTENTS_PATH=$2 # Example - ../volumes/volume1

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Copying keys from "$VOLUME_CONTENTS_PATH" to "$EXTERNAL_VOLUME_PATH""

read -p "Please insert the usb drive for $VOLUME_CONTENTS_PATH and hit enter"

sudo cp -vr $VOLUME_CONTENTS_PATH $EXTERNAL_VOLUME_PATH
