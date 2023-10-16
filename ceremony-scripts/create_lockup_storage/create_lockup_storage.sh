#!/usr/bin/env zsh

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts e:h option; do
	case "${option}" in
		e) ENV_FILE=${OPTARG};;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

SCRIPT_DIR="${SCRIPTS_DIR}/create_lockup_storage"

VOL=${VOLUMES_DIR}/volume1/lockupAdmins

addresses=$(ls $VOL)

cd ${SCRIPT_DIR} > /dev/null

npm i &>> ${LOG_FILE}

node ${SCRIPT_DIR}/createStorage.js $addresses

cd - > /dev/null

