#!/bin/bash

# Downloads via scp an inventory file containing ip address list of nodes
# Params:
#   user - user to ssh into box
#   host - host to pull file from
#   remote_file - file to scp
# Example call: get_inventory "user" "152.167.123.1" "inventory_file.txt" "../ceremony_scripts/"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

${SCRIPTS_DIR}/print_title.sh "Downloading inventory file" | tee ${LOG_FILE}

user=${1:-$SCP_USER}
host=${2:-$CONDUCTOR_NODE_URL}
remote_file=${3:-$REMOTE_INVENTORY_PATH}
local_file=${4:-$INVENTORY_PATH}

scp -i $SSH_KEY_DOWNLOAD_PATH "${user}"@"${host}":"${remote_file}" "${local_file}" &>> ${LOG_FILE}

if [ -f "$local_file" ]; then
	echo "$local_file exists."
else 
	echo "Failed to retrieve ${local_file}."
	exit 1
fi

