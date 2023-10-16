#!/usr/bin/env zsh

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

VOL=${VOLUMES_DIR}/volume1/lockupAdmins

addresses=$(ls $VOL)

cd ${SCRIPT_DIR} > /dev/null

npm i &>> ${LOG_FILE}

node ${SCRIPT_DIR}/createStorage.js $addresses

cd - > /dev/null

