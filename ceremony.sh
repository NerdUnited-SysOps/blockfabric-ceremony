#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -o : Option number (e.g., -o 1 or -o 2,1 for submenu)"
	echo "  --besu : Use Besu validation and deployment"
	echo "  --dry-run : Preview persistence actions without executing"
	echo "  -h : This help message"
}

# Pre-process --besu flag (getopts doesn't support long options)
args=()
for arg in "$@"; do
    case "$arg" in
        --besu) BESU_MODE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

while getopts e:hdo: option; do
	case "${option}" in
		d) DEV_ENABLED="true";;
		e) ENV_FILE=${OPTARG};;
		o)
			OPT_PARTS=(${(s:,:)OPTARG})
			DIRECT_OPTION=${OPT_PARTS[1]}
			DIRECT_SUBOPTION=${OPT_PARTS[2]:-}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

check_env() {
	var_name=$1
	var_val=$2
	[[ -z "${var_val}" ]] && echo "$0:${LINENO} .env is missing ${var_name} variable" && exit 1
}

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo "${0}:${LINENO} .env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "${0}:${LINENO} SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1
[[ -z "${CHAIN_NAME}" ]] && echo "${0}:${LINENO} .env is missing CHAIN_NAME variable" && exit 1
[[ -z "${NETWORK_TYPE}" ]] && echo "${0}:${LINENO} .env is missing NETWORK_TYPE variable" && exit 1

check_file_path() {
	file_path=$1
	if [ ! -f "${file_path}" ]; then
		echo "Cannot find ${file_path}"
		exit 1
	fi
}

usage() {
	printf "Welcome! This is an interface for working with the ceremony.\n"
	printf "You may select from the options below\n\n"
}

create_blockchain() {
	check_file_path "${SCRIPTS_DIR}/create_blockchain.sh"
	${SCRIPTS_DIR}/create_blockchain.sh -e "${ENV_FILE}" ${BESU_MODE:+--besu} ${DEV_ENABLED:+-d}
}

run_validation() {
	./validation.sh -e "${ENV_FILE}" ${BESU_MODE:+--besu} ${DEV_ENABLED:+-d}
}

persistence() {
	./persistence.sh -e "${ENV_FILE}" | tee -a "${LOG_FILE}"
}

deploy_bridge() {
    ./bridge.sh
}

dev() {
	check_file_path "${SCRIPTS_DIR}/dev.sh"
	${SCRIPTS_DIR}/dev.sh -e "${ENV_FILE}" ${BESU_MODE:+--besu} ${DEV_ENABLED:+-d}
}

items=(
	"Create blockchain"
	"Run validation"
	"Persist assets"
	# "Deploy Bridge"
	"Exit"
)

[ -n "${DEV_ENABLED}" ] && items+=("Devz")

NC='\033[0m'
RED='\033[0;31m'

if [[ -n "${DIRECT_OPTION}" ]]; then
	if [[ ! "${DIRECT_OPTION}" =~ '^[0-9]+$' ]]; then
		printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} is not a valid option number\n\n"
		exit 1
	fi
	SUB_FLAG=()
	[[ -n "${DIRECT_SUBOPTION}" ]] && SUB_FLAG=(-o "${DIRECT_SUBOPTION}")
	case ${DIRECT_OPTION} in
		1) create_blockchain;;
		2) ./validation.sh -e "${ENV_FILE}" ${BESU_MODE:+--besu} ${DEV_ENABLED:+-d} "${SUB_FLAG[@]}";;
		3) ./persistence.sh -e "${ENV_FILE}" ${DRY_RUN:+--dry-run} | tee -a "${LOG_FILE}";;
		4) printf "Closing\n\n"; exit 1;;
		5)
			if [[ -n "${DEV_ENABLED}" ]]; then
				check_file_path "${SCRIPTS_DIR}/dev.sh"
				${SCRIPTS_DIR}/dev.sh -e "${ENV_FILE}" ${BESU_MODE:+--besu} "${SUB_FLAG[@]}" ${DEV_ENABLED:+-d}
			else
				printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"
				exit 1
			fi;;
		*) printf "\n\nOoos, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1;;
	esac
	exit 0
fi

clear -x

usage

mode_label=""
[[ -n "${BESU_MODE}" ]] && mode_label=" [Besu]"

while true; do
	COLUMNS=1
	PS3=$'\n'"${CHAIN_NAME} ${NETWORK_TYPE}${mode_label} | Select option: "
	select item in "${items[@]}"
		case $REPLY in
			1) clear -x; create_blockchain; break;;
			2) clear -x; run_validation; break;;
			3) clear -x; persistence; break;;
			# 4) clear -x; deploy_bridge; break;;
			4) printf "Closing\n\n"; exit 1;;
			5) clear -x; dev; break;;
			*)
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done
