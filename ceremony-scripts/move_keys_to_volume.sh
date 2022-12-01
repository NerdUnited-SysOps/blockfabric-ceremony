#!/bin/bash

EXTERNAL_VOLUME_PATH=$1 # Example - /dev/sdc1
VOLUME_CONTENTS_PATH=$2 # Example - ../volumes/volume1

${SCRIPTS_DIR}/print_title.sh "Moving keys from "$VOLUME_CONTENTS_PATH" to "$EXTERNAL_VOLUME_PATH""

read -p "Please insert the usb drive for $VOLUME_CONTENTS_PATH and hit enter"

umount $EXTERNAL_VOLUME_PATH

sudo mkfs.exfat $EXTERNAL_VOLUME_PATH

sudo fsck $EXTERNAL_VOLUME_PATH

mv $VOLUME_CONTENTS_PATH $EXTERNAL_VOLUME_PATH

