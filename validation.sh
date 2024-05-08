#!/usr/bin/env zsh

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts he: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${VOLUMES_DIR}" ]] && echo ".env is missing VOLUMES_DIR variable" && exit 1
[[ -z "${LOG_FILE}" ]] && echo ".env is missing LOG_FILE variable" && exit 1

# #############################
# Working with volumes
# #############################

volume_prompt_intro() {
	printf "Inspecting volumes within ${VOLUMES_DIR}\n"
	printf "Select subdirectory.\n\n"
}

volume_prompt() {
	volume=""

	PS3=$'\n'"Select volume: "
	select item in volume1 volume2; do
		case $REPLY in
			*) volume="volume${REPLY}"; break;;
		esac
	done
	echo "${volume}"
}

inspect_volumes() {
	volume_prompt_intro
	volume=$(volume_prompt)

	printf "\n"
	${SCRIPTS_DIR}/validation/validate_accounts.sh \
		-e "${ETHKEY_PATH}" \
		-p "${VOLUMES_DIR}/${volume}"
	printf "\n\n"
}

list_volume_content() {
	[[ ! -d "${VOLUMES_DIR}" ]] && echo "VOLUMES_DIR environment variable is not a directory. Expecting it here ${VOLUMES_DIR}" && exit 1
	volume_prompt_intro
	volume=$(volume_prompt)

	printf "\n"
	printf "Executing: tree ${VOLUMES_DIR}/${volume} | less\n\n" | tee -a ${LOG_FILE}
	tree ${VOLUMES_DIR}/${volume} | tee -a ${LOG_FILE} | less
	printf "\n\n"
}

list_volume_sizes() {
	printf "\n"
	printf "Executing: ls ${VOLUMES_DIR}/volume1 -alR | less\n\n" | tee -a ${LOG_FILE}
	ls ${VOLUMES_DIR}/volume1 -alR | tee -a ${LOG_FILE}

	printf "Executing: ls ${VOLUMES_DIR}/volume2 -alR | less\n\n" | tee -a ${LOG_FILE}
	ls ${VOLUMES_DIR}/volume2 -alR | tee -a ${LOG_FILE}
	printf "\n\n"
}

list_addreses() {
	printf "\n"
	printf "Executing: grep -r -o \"address\\\":\\\"[a-f0-9]*\\\"\" ${VOLUMES_DIR}/volume1 | sed 's/\\/keystore\\:address\\\"\:\\\"/\\\t\\\t/g' | tr -d '\"'\n\n" | tee -a ${LOG_FILE}
	grep -r -o "address\":\"[a-f0-9]*\"" ${VOLUMES_DIR}/volume1 \
		| sed 's/\/keystore\:address\"\:\"/\t\t/g' \
		| tr -d '"' \
		| tee -a ${LOG_FILE}

	printf "Executing: grep -r -o \"address\\\":\\\"[a-f0-9]*\\\"\" ${VOLUMES_DIR}/volume2 | sed 's/\\/keystore\\:address\\\"\:\\\"/\\\t\\\t/g' | tr -d '\"'\n\n" | tee -a ${LOG_FILE}
	grep -r -o "address\":\"[a-f0-9]*\"" ${VOLUMES_DIR}/volume2 \
		| sed 's/\/keystore\:address\"\:\"/\t\t/g' \
		| tr -d '"' \
		| tee -a ${LOG_FILE}
	printf "\n\n"
}

# #############################
# Reaching out to the chain
# #############################

run_validation() {
	printf "Validating chain...\n\n"
	${SCRIPTS_DIR}/validation/run_validation.sh -e "${ENV_FILE}"
	printf "\n\nNote: It takes a minute for all nodes to catch up with their peers.\n\n"
}

print_account_range() {
	./exec_chain.sh -e "${ENV_FILE}" "debug.accountRange()" | tee -a ${LOG_FILE}
	printf "\n\n"
}

usage() {
	printf "This is an interface for validation of the ceremony.\n"
	printf "You may select from the options below\n\n"
}

items=(
	"General health"
	"Print chain accounts"
	"List addresses"
	"List volume sizes"
	"Exit"
)

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"${CHAIN_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}"
		case $REPLY in
			1) clear -x; run_validation | tee -a ${LOG_FILE}; break;;
			2) clear -x; print_account_range; break;;
			3) clear -x; list_addreses; break;;
			4) clear -x; list_volume_sizes; break;;
			5) printf "Closing.\n\n"; exit 0;;
			*)
				printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

