#!/usr/bin/env zsh

set -e

SECONDS=0

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -e : Path to .env file"
  echo "  -d : Enable verbose Ansible output (dev mode)"
  echo "  -i : Install dependencies"
  echo "  -r : Reset the ceremony"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

# Pre-process --besu flag (getopts does not support long options)
args=()
for arg in "$@"; do
    case "$arg" in
        --besu) BESU_MODE=true ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

while getopts 'b:de:hi' option; do
	case "$option" in
		d)
			DEBUG_MODE=true
			;;
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		i)
			${SCRIPTS_DIR}/install_dependencies.sh
			exit 0
			;;
		r)
			${SCRIPTS_DIR}/reset.sh
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

if [ ! -f "${ENV_FILE}" ]; then
	echo "Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${LOG_FILE}" ]] && echo ".env is missing LOG_FILE variable" && exit 1

get_list_of_validator_ips () {
	[[ -z "${INVENTORY_PATH}" ]] && echo ".env is missing INVENTORY_PATH variable" && exit 1
	[[ ! -f "${INVENTORY_PATH}" ]] && echo "inventory path not found. Expected it here: ${INVENTORY_PATH}" && exit 1
	ansible validator \
		--list-hosts \
		-i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_single_rpc_ip () {
	[[ -z "${INVENTORY_PATH}" ]] && echo ".env is missing INVENTORY_PATH variable" && exit 1
	[[ ! -f "${INVENTORY_PATH}" ]] && echo "inventory path not found. Expected it here: ${INVENTORY_PATH}" && exit 1
	ansible rpc \
		--list-hosts \
		-i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | head -n 1
}

printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "Cannot find ${SCRIPTS_DIR}/printer.sh" && exit 1
	${SCRIPTS_DIR}/printer.sh "$@"
}

check_env() {
	var_name=$1
	var_val=$2
	[[ -z "${var_val}" ]] && printer -e ".env is missing ${var_name} variable"
}

check_env_dir() {
	var_name=$1
	var_val=$2
	[[ -z "${var_val}" ]] && printer -e ".env is missing ${var_name} variable"
}

check_env_file() {
	file_path=$1
	if [ ! -f "${file_path}" ]; then
		printer -e "Cannot find ${file_path}"
	fi
}

get_ansible_vars() {
	[[ -z "${ANSIBLE_DIR}" ]] && echo ".env is missing ANSIBLE_DIR variable" && exit 1
	[[ -z "${BRAND_ANSIBLE_URL}" ]] && echo ".env is missing BRAND_ANSIBLE_URL variable" && exit 1

	printer -t "Fetching ansible variables"

	if [ ! -d "${ANSIBLE_DIR}" ]; then
		source ${ENV_FILE}

		if git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR} &>> ${LOG_FILE}; then
			printer -s "Fetched variables"
		else
			printer -e "Failed to fetch variables"
		fi
	else
		printer -n "Ansible variables present, skipping"
	fi
}

get_inventory() {
        [[ -z "${INVENTORY_PATH}" ]] && echo ".env is missing INVENTORY_PATH variable" && exit 1

        printer -t "Checking inventory file"

        if [ -f "${INVENTORY_PATH}" ]; then
                printer -s "$INVENTORY_PATH exists"
        else
                printer -e "Inventory not found at ${INVENTORY_PATH}"
                exit
        fi
}

install_ansible_role() {
	[[ -z "${ANSIBLE_ROLE_INSTALL_PATH}" ]] && echo ".env is missing ANSIBLE_ROLE_INSTALL_PATH variable" && exit 1
	[[ -z "${ANSIBLE_ROLE_VERSION}" ]] && echo ".env is missing ANSIBLE_ROLE_VERSION variable" && exit 1
	[[ -z "${ANSIBLE_ROLE_INSTALL_URL}" ]] && echo ".env is missing ANSIBLE_ROLE_INSTALL_URL variable" && exit 1

	printer -t "Installing Ansible role"

	if [ ! -d "${ANSIBLE_ROLE_INSTALL_PATH}" ]; then
		mkdir -p ${ANSIBLE_ROLE_INSTALL_PATH}

		if git clone \
			--depth 1 \
			--branch ${ANSIBLE_ROLE_VERSION} \
			${ANSIBLE_ROLE_INSTALL_URL} ${ANSIBLE_ROLE_INSTALL_PATH} &>> ${LOG_FILE}
		then
			printer -s "Installed role"
		else
			printer -e "Failed to install ansible role"
		fi
	else
		printer -n "Ansible role present, skipping"
	fi
}

install_besu_role() {
	[[ -z "${BESU_ROLE_SOURCE}" ]] && echo ".env is missing BESU_ROLE_SOURCE variable" && exit 1
	[[ -z "${BESU_ROLE_INSTALL_PATH}" ]] && echo ".env is missing BESU_ROLE_INSTALL_PATH variable" && exit 1
	[[ -z "${BESU_ROLE_VERSION}" ]] && echo ".env is missing BESU_ROLE_VERSION variable" && exit 1

	printer -t "Installing Besu ansible role"

	if [ ! -d "${BESU_ROLE_INSTALL_PATH}" ]; then
		if git clone \
			--depth 1 \
			--branch ${BESU_ROLE_VERSION} \
			"${BESU_ROLE_SOURCE}" "${BESU_ROLE_INSTALL_PATH}" &>> ${LOG_FILE}
		then
			printer -s "Installed Besu role"
		else
			printer -e "Failed to install Besu role"
		fi

		# Install upstream dependency (consensys.hyperledger_besu)
		if [ -f "${BESU_ROLE_INSTALL_PATH}/requirements.yml" ]; then
			ansible-galaxy install -r "${BESU_ROLE_INSTALL_PATH}/requirements.yml" &>> ${LOG_FILE}
			printer -s "Installed Besu role dependencies"
		fi
	else
		printer -n "Besu role present, skipping"
	fi
}

run_ansible() {
	[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable"
	[[ -z "${ANSIBLE_CHAIN_DEPLOY_FORKS}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing ANSIBLE_CHAIN_DEPLOY_FORKS variable"

	printer -t "Executing Ansible Playbook"

	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_CEREMONY_DIR}/goquorum.yaml

	[ ! $? -eq 0 ] && printer -e "Failed to execute ansible playbook"
}

clear -x

printer -b

[[ ! -f "${SCRIPTS_DIR}/install_dependencies.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/install_dependencies.sh file doesn't exist" && exit 1
${SCRIPTS_DIR}/install_dependencies.sh -e "${ENV_FILE}" | tee -a "${LOG_FILE}"

[[ ! -f "${SCRIPTS_DIR}/get_secrets.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/get_secrets.sh file doesn't exist" && exit 1
${SCRIPTS_DIR}/get_secrets.sh -e ${ENV_FILE} | tee -a "${LOG_FILE}"

get_ansible_vars

if [[ -n "${BESU_MODE}" ]]; then
	install_besu_role
else
	install_ansible_role
fi
get_inventory

[[ ! -f "${SCRIPTS_DIR}/get_contract_bytecode.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/get_contract_bytecode.sh file doesn't exist" && exit 1
${SCRIPTS_DIR}/get_contract_bytecode.sh \
	-e "${ENV_FILE}" | tee -a "${LOG_FILE}"

VALIDATOR_IPS=$(get_list_of_validator_ips)

[[ ! -f "${SCRIPTS_DIR}/create_all_wallets.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/create_all_wallets.sh file doesn't exist" && exit 1
${SCRIPTS_DIR}/create_all_wallets.sh \
	-e "${ENV_FILE}" \
	-i "${VALIDATOR_IPS}" | tee -a "${LOG_FILE}"

[[ ! -f "${SCRIPTS_DIR}/generate_dao_storage.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/generate_dao_storage.sh file doesn't exist" && exit 1
if [[ -n "${BESU_MODE}" ]]; then
	${SCRIPTS_DIR}/generate_dao_storage.sh \
		-e "${ENV_FILE}" \
		-i "$VALIDATOR_IPS" \
		--besu | tee -a "${LOG_FILE}"
else
	${SCRIPTS_DIR}/generate_dao_storage.sh \
		-e "${ENV_FILE}" \
		-i "$VALIDATOR_IPS" | tee -a "${LOG_FILE}"
fi

[[ ! -f "${SCRIPTS_DIR}/generate_ansible_vars.sh" ]] && echo "${0}:${LINENO} ${SCRIPTS_DIR}/generate_ansible_vars.sh file doesn't exist" && exit 1
if [[ -n "${BESU_MODE}" ]]; then
	${SCRIPTS_DIR}/generate_ansible_vars.sh \
		-e "${ENV_FILE}" \
		-v "$VALIDATOR_IPS" \
		--besu | tee -a "${LOG_FILE}"
else
	${SCRIPTS_DIR}/generate_ansible_vars.sh \
		-e "${ENV_FILE}" \
		-v "$VALIDATOR_IPS" | tee -a "${LOG_FILE}"
fi

if [[ -n "${BESU_MODE}" ]]; then
	source "${SCRIPTS_DIR}/ansible_helpers.sh"


	printer -t "Deploying Besu QBFT network"
	ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_FORCE_COLOR=True \
	ANSIBLE_ROLES_PATH="${ANSIBLE_ROLE_DIR}/..:${HOME}/.ansible/roles" \
		run_ansible_logged "${LOG_FILE}" \
		-e "ansible_ssh_private_key_file=${AWS_NODES_SSH_KEY_PATH}" \
		-i "${INVENTORY_PATH}" \
		"${ANSIBLE_ROLE_DIR}/test/validate.yml"
	printer -s "Deployment complete"
else
	run_ansible
fi

duration=$SECONDS
printer -s "Execution Completed in $(($duration / 60)) minutes $(($duration % 60)) seconds"

printer -f 40
