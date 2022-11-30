#!/bin/bash

# Downloads via scp an inventory file containing ip address list of nodes
# Params:
#   user - user to ssh into box
#   host - host to pull file from
#   file - file to scp
# Example call: get_inventory "user" "152.167.123.1" "inventory_file.txt" "../ceremony_scripts/"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

echo "Downloading inventory file" | tee ${LOG_FILE}

user=$1
host=$2
file=$3
local_file=$4
scp -i $SSH_KEY_DOWNLOAD_PATH "$user"@"$host":"$file" "$local_file" &>> ${LOG_FILE}

if [ -f "$local_file" ]; then
	echo "$local_file exists."
else 
	echo "$local_file does not exist."
	exit 1
fi
