#!/usr/bin/env zsh

usage() {
	echo "Options"
	echo "  -e : Environment config file"
	echo "  -o : Option number for non-interactive selection"
	echo "  -h : This help message"
}

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
	${SCRIPTS_DIR}/validation/validate_chain_besu.sh \
		-i $INVENTORY_PATH \
		-p $RPC_PORT \
		-r $RPC_PATH \
		-v ${SCRIPTS_DIR}/validation/remoteValidate_besu.sh
	printf "\n\nNote: It takes a minute for all nodes to catch up with their peers.\n\n"
}

print_account_range() {
	${SCRIPTS_DIR}/validation/besu_account_range.sh -e "${ENV_FILE}" | tee -a ${LOG_FILE}
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

extract_private_key() {
	local wallet_path=$1
	local pk_file="${wallet_path}/privatekey"
	if [[ ! -f "${pk_file}" ]]; then
		local inspected=$(${ETHKEY_PATH} inspect --private --passwordfile "${wallet_path}/password" "${wallet_path}/keystore")
		echo "${inspected}" | grep "Private" | awk '{print $3}' | tr -d '\n' > "${pk_file}"
	fi
}

safe_test() {
	local subcommand=$1
	local BIN=$(build_ceremony_test)
	local validator_ip=$(ansible --list-hosts -i "${INVENTORY_PATH}" validator | sed '/:/d ; s/ //g' | head -1)

	# Extract private keys from keystores if not already done
	extract_private_key "${VOLUMES_DIR}/volume1/safeOwner1"
	extract_private_key "${VOLUMES_DIR}/volume2/safeOwner2"
	extract_private_key "${VOLUMES_DIR}/volume3/safeOwner3"

	RPC_URL="http://${validator_ip}:${RPC_PORT}" \
	SAFE_PROXY_ADDRESS="${SAFE_PROXY_ADDRESS}" \
	SAFE_OWNER_1_KEY_PATH="${VOLUMES_DIR}/volume1/safeOwner1/privatekey" \
	SAFE_OWNER_2_KEY_PATH="${VOLUMES_DIR}/volume2/safeOwner2/privatekey" \
	SAFE_OWNER_3_KEY_PATH="${VOLUMES_DIR}/volume3/safeOwner3/privatekey" \
		"$BIN" "$subcommand"
}

test_lockup_set_paused() { safe_test "test-lockup-set-paused"; }
test_lockup_set_daily_limit() { safe_test "test-lockup-set-daily-limit"; }
test_lockup_set_issuer() { safe_test "test-lockup-set-issuer"; }
test_distribution_set_issuer() { safe_test "test-distribution-set-issuer"; }

usage() {
	printf "This is an interface for validation of the ceremony.\n"
	printf "You may select from the options below\n\n"
}

items=(
	"General health"
	"Show genesis"
	"List addresses"
	"List volume sizes"
	"Print chain accounts"
)

[ -n "${DEV_ENABLED}" ] && items+=("Show startup config" "Validate genesis" "Test distribution" "Test vote" "Test create contract" "Test lockup setPaused" "Test lockup setDailyLimit" "Test lockup setIssuer" "Test distribution setIssuer")

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
		5) print_account_range;;
		6) [[ -n "${DEV_ENABLED}" ]] && show_startup_config | tee -a ${LOG_FILE} || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		7) [[ -n "${DEV_ENABLED}" ]] && validate_genesis | tee -a ${LOG_FILE} || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		8) [[ -n "${DEV_ENABLED}" ]] && test_distribution || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		9) [[ -n "${DEV_ENABLED}" ]] && test_vote || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		10) [[ -n "${DEV_ENABLED}" ]] && test_create_contract || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		11) [[ -n "${DEV_ENABLED}" ]] && test_lockup_set_paused || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		12) [[ -n "${DEV_ENABLED}" ]] && test_lockup_set_daily_limit || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		13) [[ -n "${DEV_ENABLED}" ]] && test_lockup_set_issuer || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
		14) [[ -n "${DEV_ENABLED}" ]] && test_distribution_set_issuer || { printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} requires -d flag\n\n"; exit 1; };;
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
		case $item in
			"General health") clear -x; run_validation | tee -a ${LOG_FILE}; break;;
			"Show genesis") clear -x; show_genesis | tee -a ${LOG_FILE}; break;;
			"List addresses") clear -x; list_addreses; break;;
			"List volume sizes") clear -x; list_volume_sizes; break;;
			"Print chain accounts") clear -x; print_account_range; break;;
			"Show startup config") clear -x; show_startup_config | tee -a ${LOG_FILE}; break;;
			"Validate genesis") clear -x; validate_genesis | tee -a ${LOG_FILE}; break;;
			"Test distribution") clear -x; test_distribution; break;;
			"Test vote") clear -x; test_vote; break;;
			"Test create contract") clear -x; test_create_contract; break;;
			"Test lockup setPaused") clear -x; test_lockup_set_paused; break;;
			"Test lockup setDailyLimit") clear -x; test_lockup_set_daily_limit; break;;
			"Test lockup setIssuer") clear -x; test_lockup_set_issuer; break;;
			"Test distribution setIssuer") clear -x; test_distribution_set_issuer; break;;
			"Exit") printf "Closing.\n\n"; exit 0;;
			*)
				printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

