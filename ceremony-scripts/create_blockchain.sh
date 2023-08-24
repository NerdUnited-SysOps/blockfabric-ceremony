#!/usr/bin/env zsh

set -e

SECONDS=0

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -e : Path to .env file"
  echo "  -i : Install dependencies"
  echo "  -r : Reset the ceremony"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

while getopts 'b:d:e:hi' option; do
	case "$option" in
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
[[ ! -f "${LOG_FILE}" ]] && echo "LOG_FILE environment variable is not a file. Expecting it here ${LOG_FILE}" && exit 1

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
	[[ ! -d "${ANSIBLE_DIR}" ]] && echo "ANSIBLE_DIR environment variable is not a directory. Expecting it here ${ANSIBLE_DIR}" && exit 1
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
	[[ -z "${AWS_CONDUCTOR_SSH_KEY_PATH}" ]] && echo ".env is missing AWS_CONDUCTOR_SSH_KEY_PATH variable" && exit 1
	[[ -z "${SCP_USER}" ]] && echo ".env is missing SCP_USER variable" && exit 1
	[[ -z "${CONDUCTOR_NODE_URL}" ]] && echo ".env is missing CONDUCTOR_NODE_URL variable" && exit 1
	[[ -z "${REMOTE_INVENTORY_PATH}" ]] && echo ".env is missing REMOTE_INVENTORY_PATH variable" && exit 1
	printer -t "Downloading inventory file"

	scp -o StrictHostKeyChecking=no \
		-i ${AWS_CONDUCTOR_SSH_KEY_PATH} \
		"${SCP_USER}"@"${CONDUCTOR_NODE_URL}":"${REMOTE_INVENTORY_PATH}" \
		"${INVENTORY_PATH}"

	if [ -n "${$?}" ] && [ -f "$INVENTORY_PATH" ]; then
		printer -s "$INVENTORY_PATH exists."
	else
		printer -e "Failed to retrieve inventory"
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

run_ansible() {
	check_env "ANSIBLE_CHAIN_DEPLOY_FORKS" "${ANSIBLE_CHAIN_DEPLOY_FORKS}"
	check_env "AWS_NODES_SSH_KEY_PATH" "${AWS_NODES_SSH_KEY_PATH}"

	printer -t "Executing Ansible Playbook"

	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml

	[ ! $? -eq 0 ] && printer -e "Failed to execute ansible playbook"
}

clear -x

printer -b

check_env_file "${SCRIPTS_DIR}/install_dependencies.sh"
${SCRIPTS_DIR}/install_dependencies.sh -e "${ENV_FILE}"

check_env_file "${SCRIPTS_DIR}/get_secrets.sh"
${SCRIPTS_DIR}/get_secrets.sh -f ${ENV_FILE}

get_ansible_vars
install_ansible_role
get_inventory

check_env_file "${SCRIPTS_DIR}/get_contract_bytecode.sh"
${SCRIPTS_DIR}/get_contract_bytecode.sh

VALIDATOR_IPS=$(get_list_of_validator_ips)

check_env_file "${SCRIPTS_DIR}/create_all_wallets.sh"
${SCRIPTS_DIR}/create_all_wallets.sh -e "${ENV_FILE}" -i "${VALIDATOR_IPS}"

check_env_file "${SCRIPTS_DIR}/generate_dao_storage.sh"
${SCRIPTS_DIR}/generate_dao_storage.sh -i "$VALIDATOR_IPS"

check_env_file "${SCRIPTS_DIR}/generate_ansible_vars.sh"
${SCRIPTS_DIR}/generate_ansible_vars.sh -v "$VALIDATOR_IPS"

# Executing ansible returns a non-zero code even when it's successful.
# Backgrounding the task stops the script from existing.
run_ansible &
wait

duration=$SECONDS
printer -s "Execution Completed in $(($duration / 60)) minutes $(($duration % 60)) seconds"

printer -f 40

