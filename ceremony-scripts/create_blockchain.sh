#!/usr/bin/zsh

set -e

SECONDS=0

SCRIPTS_DIR=$(dirname ${(%):-%N})
BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
VOLUMES_DIR=${BASE_DIR}/volumes
ANSIBLE_DIR=${BASE_DIR}/ansible
INVENTORY_PATH=${ANSIBLE_DIR}/inventory
SCP_USER=admin
ENV_FILE=${BASE_DIR}/.env

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -d : Data directory on external volume"
	echo "  -f : Path to .env file"
  echo "  -i : Install dependencies"
  echo "  -r : Reset the ceremony"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

while getopts 'b:d:f:hi' option; do
	case "$option" in
		f)
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
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

get_list_of_validator_ips () {
	ansible validator \
		--list-hosts \
		-i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_single_rpc_ip () {
	ansible rpc \
		--list-hosts \
		-i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | head -n 1
}

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

generate_wallet() {
	${SCRIPTS_DIR}/generate_wallet.sh "$@"
}

get_ansible_vars() {
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
	printer -t "Downloading inventory file"

	scp -o StrictHostKeyChecking=no \
		-i ${AWS_CONDUCTOR_SSH_KEY_PATH} \
		"${SCP_USER}"@"${CONDUCTOR_NODE_URL}":"${REMOTE_INVENTORY_PATH}" \
		"${INVENTORY_PATH}"

	if [ -n "${$?}" ] && [ -f "$INVENTORY_PATH" ]; then
		printer -s "$INVENTORY_PATH exists."
	else
		printer -e "Failed to retrieve ${local_file}"
	fi
}

install_ansible_role() {
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
	printer -t "Executing Ansible Playbook"
	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		--forks 20 \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml

	[ ! $? -eq 0 ] && printer -e "Failed to execute ansible playbook"
}

copy_logs() {
	printer -t "Moving ${LOG_FILE} file to all volumes"

	[ -f "${LOG_FILE}" ] || touch ${LOG_FILE}
	cp $LOG_FILE ${VOLUMES_DIR}/volume1
	cp $LOG_FILE ${VOLUMES_DIR}/volume2
	cp $LOG_FILE ${VOLUMES_DIR}/volume3
	cp $LOG_FILE ${VOLUMES_DIR}/volume4

	printer -s "Successfully moved ${LOG_FILE} file to all volumes"
}

clear -x

printer -b
if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

#${SCRIPTS_DIR}/install_dependencies.sh

if [ $ENV = "dev" ]; then
    ${SCRIPTS_DIR}/get_secrets_local.sh -f ${ENV_FILE}
else
    ${SCRIPTS_DIR}/get_secrets.sh -f ${ENV_FILE}
fi

get_ansible_vars
install_ansible_role
#get_inventory

${SCRIPTS_DIR}/get_contract_bytecode.sh

VALIDATOR_IPS=$(get_list_of_validator_ips)
${SCRIPTS_DIR}/create_all_wallets.sh -i "${VALIDATOR_IPS}"
${SCRIPTS_DIR}/generate_dao_storage.sh -i "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_ansible_vars.sh -v "$VALIDATOR_IPS"

copy_logs

# Executing ansible returns a non-zero code even when it's successful.
# Backgrounding the task stops the script from existing.
run_ansible &
wait

duration=$SECONDS
printer -s "Execution Completed in $(($duration / 60)) minutes $(($duration % 60)) seconds"

printer -f 40

