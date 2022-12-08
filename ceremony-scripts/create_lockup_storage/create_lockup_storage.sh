#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../../.common.sh


VOL=${VOLUMES_DIR}/volume1/lockupAdmins

addresses=$(ls $VOL)
# echo $addresses

npm i &>> ${LOG_FILE}

node ./createStorage.js $addresses



# echo > list_of_addresses.txt

# for address in #addresses
# do
# 				x=$(echo $address | openssl dgst -sha3-256)
# 				echo "${X}: \"01\""
# 
# done
