#!/usr/bin/env zsh

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -o : Option number for non-interactive selection"
	echo "  --besu : Use Besu validation scripts"
	echo "  -h : This help message"
}

# Pre-process --besu flag (getopts doesn't support long options)
args=()
for arg in "$@"; do
	case "$arg" in
		--besu) BESU_MODE=true ;;
		*) args+=("$arg") ;;
	esac
done
set -- "${args[@]}"

while getopts de:ho: option; do
	case "${option}" in
		d) DEV_ENABLED="true";;
		e)
			ENV_FILE=${OPTARG}
			;;
		o)
			DIRECT_OPTION=${OPTARG}
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
	if [[ -n "${BESU_MODE}" ]]; then
		${SCRIPTS_DIR}/validation/validate_chain_besu.sh \
			-i $INVENTORY_PATH \
			-p $RPC_PORT \
			-r $RPC_PATH \
			-v ${SCRIPTS_DIR}/validation/remoteValidate_besu.sh
	else
		${SCRIPTS_DIR}/validation/run_validation.sh -e "${ENV_FILE}"
	fi
	printf "\n\nNote: It takes a minute for all nodes to catch up with their peers.\n\n"
}

print_account_range() {
	if [[ -n "${BESU_MODE}" ]]; then
		${SCRIPTS_DIR}/validation/besu_account_range.sh -e "${ENV_FILE}" | tee -a ${LOG_FILE}
	else
		./exec_chain.sh -e "${ENV_FILE}" "debug.accountRange()" | tee -a ${LOG_FILE}
	fi
	printf "\n\n"
}

show_startup_config() {
	${SCRIPTS_DIR}/validation/inspect_node.sh -e "${ENV_FILE}" -m config
}

show_genesis() {
	${SCRIPTS_DIR}/validation/inspect_node.sh -e "${ENV_FILE}" -m genesis
}

validate_genesis() {
	${SCRIPTS_DIR}/validation/validate_genesis.sh -e "${ENV_FILE}"
}

build_ceremony_test() {
	local BIN="${SCRIPTS_DIR}/validation/ceremony-tests/ceremony-test"
	if [[ ! -x "$BIN" ]]; then
		(cd "${SCRIPTS_DIR}/validation/ceremony-tests" && go mod tidy && go build -o ceremony-test .) &>> ${LOG_FILE}
	fi
	echo "$BIN"
}

test_distribution() {
	local BIN=$(build_ceremony_test)
	local validator_ip=$(ansible --list-hosts -i "${INVENTORY_PATH}" validator | sed '/:/d ; s/ //g' | head -1)

	RPC_URL="http://${validator_ip}:${RPC_PORT}" \
	ISSUER_KEY_PATH="${VOLUMES_DIR}/volume2/distributionIssuer/privatekey" \
	RECIPIENT_KEY_PATH="${VOLUMES_DIR}/volume1/besu-v-1/account/privatekey" \
		"$BIN" distribute
}

test_vote() {
	local BIN=$(build_ceremony_test)
	local validator_ip=$(ansible --list-hosts -i "${INVENTORY_PATH}" validator | sed '/:/d ; s/ //g' | head -1)

	RPC_URL="http://${validator_ip}:${RPC_PORT}" \
	DAO_ADDRESS="0x5a443704dd4B594B382c22a083e2BD3090A6feF3" \
	VOLUMES_DIR="${VOLUMES_DIR}" \
		"$BIN" vote
}

test_create_contract() {
	local BIN=$(build_ceremony_test)
	local validator_ip=$(ansible --list-hosts -i "${INVENTORY_PATH}" validator | sed '/:/d ; s/ //g' | head -1)

	RPC_URL="http://${validator_ip}:${RPC_PORT}" \
	DEPLOYER_KEY_PATH="${VOLUMES_DIR}/volume2/distributionIssuer/privatekey" \
		"$BIN" create-contract
}

usage() {
	printf "This is an interface for validation of the ceremony.\n"
	printf "You may select from the options below\n\n"
}

items=(
	"General health"
	"Show genesis"
	"List addresses"
	"List volume sizes"
	"Show startup config"
	"Print chain accounts"
	"Validate genesis"
)

[ -n "${DEV_ENABLED}" ] && items+=("Test distribution" "Test vote" "Test create contract")

items+=("Exit")

NC='\033[0m'
RED='\033[0;31m'

if [[ -n "${DIRECT_OPTION}" ]]; then
	if [[ ! "${DIRECT_OPTION}" =~ '^[0-9]+$' ]]; then
		printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} is not a valid option number\n\n"
		exit 1
	fi
	case ${DIRECT_OPTION} in
		1) run_validation | tee -a ${LOG_FILE};;
		2) show_genesis | tee -a ${LOG_FILE};;
		3) list_addreses;;
		4) list_volume_sizes;;
		5) show_startup_config | tee -a ${LOG_FILE};;
		6) print_account_range;;
		7) validate_genesis | tee -a ${LOG_FILE};;
		8) [[ -n "${DEV_ENABLED}" ]] && test_distribution || { printf "Closing.\n\n"; exit 0; };;
		9) [[ -n "${DEV_ENABLED}" ]] && test_vote || { printf "\n\nOoops, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1; };;
		10) [[ -n "${DEV_ENABLED}" ]] && test_create_contract || { printf "\n\nOoops, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1; };;
		11) [[ -n "${DEV_ENABLED}" ]] && { printf "Closing.\n\n"; exit 0; } || { printf "\n\nOoops, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1; };;
		*) printf "\n\nOoops, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1;;
	esac
	exit 0
fi

clear -x

usage

while true; do
	COLUMNS=1
	PS3=$'\n'"${CHAIN_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}"
		case $REPLY in
			1) clear -x; run_validation | tee -a ${LOG_FILE}; break;;
			2) clear -x; show_genesis | tee -a ${LOG_FILE}; break;;
			3) clear -x; list_addreses; break;;
			4) clear -x; list_volume_sizes; break;;
			5) clear -x; show_startup_config | tee -a ${LOG_FILE}; break;;
			6) clear -x; print_account_range; break;;
			7) clear -x; validate_genesis | tee -a ${LOG_FILE}; break;;
			8)
				if [[ -n "${DEV_ENABLED}" ]]; then
					clear -x; test_distribution; break
				else
					printf "Closing.\n\n"; exit 0
				fi;;
			9)
				if [[ -n "${DEV_ENABLED}" ]]; then
					clear -x; test_vote; break
				else
					printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n"
					usage; break
				fi;;
			10)
				if [[ -n "${DEV_ENABLED}" ]]; then
					clear -x; test_create_contract; break
				else
					printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n"
					usage; break
				fi;;
			11) printf "Closing.\n\n"; exit 0;;
			*)
				printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

