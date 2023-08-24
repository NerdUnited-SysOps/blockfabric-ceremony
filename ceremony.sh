#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts e:hd option; do
	case "${option}" in
		d) DEV_ENABLED="true";;
		e) ENV_FILE=${OPTARG};;
		h)
			usage
			exit 0
			;;
	esac
done



if [ ! -f "${ENV_FILE}" ]; then
	echo "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

[[ ! -f "${ENV_FILE}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1
[[ -z "${CHAIN_NAME}" ]] && echo ".env is missing CHAIN_NAME variable" && exit 1
[[ -z "${NETWORK_TYPE}" ]] && echo ".env is missing NETWORK_TYPE variable" && exit 1



usage() {
	printf "Welcome! This is an interface for working with the ceremony.\n"
	printf "You may select from the options below\n\n"
}

create_blockchain() {
	${SCRIPTS_DIR}/create_blockchain.sh
}

run_validation() {
	./validation.sh
}

persistence() {
	./persistence.sh
}

deploy_bridge() {
    ./bridge.sh
}

dev() {
	${SCRIPTS_DIR}/dev.sh
}

items=(
	"Create blockchain"
	"Run validation"
	"Persist assets"
	"Deploy Bridge"
	"Exit"
)

[ -n "${DEV_ENABLED}" ] && items+=("Devz")

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"${CHAIN_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}"
		case $REPLY in
			1) clear -x; create_blockchain; break;;
			2) clear -x; run_validation; break;;
			3) clear -x; persistence; break;;
			4) clear -x; deploy_bridge; break;;
			5) printf "Closing\n\n"; exit 1;;
			6) clear -x; dev; break;;
			*)
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

