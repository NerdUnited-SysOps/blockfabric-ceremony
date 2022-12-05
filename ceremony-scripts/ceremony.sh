#!/bin/bash
# Script `ceremony`

# TODO: (Need to haves)
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Make sure you can support and test with 2 copies of each volume

# Pull in brand specific variables for network (chainid, brand name, etc)
# Find out names for variables to be kept in the secrets manager

# TODO: (Nice to haves)
# Change name away from "ansible" inside the templates for ansible dir
# Make the .env file a parameter you pas to the script
# consistent formatting
# sensible error checking
# standardize individual scripts
# * Standardized inputs
# * Standardized output
# * All output redirected to logs
# Implement a verbose mode to output to logs and stdout
# Verification step in code

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -b : Brand name"
  echo "  -d : Data directory on external volume"
  echo "  -i : Install dependencies"
  echo "  -r : Reset the ceremony"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

while getopts 'b:d:hi' option; do
	case "$option" in
		b)
			BRAND_NAME="${OPTARG}"
			;;
		d)
			DESTINATION_DIR="${OPTARG}"
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

get_list_of_validator_ips () {
    ansible validator \
			--limit validator \
			--list-hosts \
			-i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

# validate required params
if [ ! "$DESTINATION_DIR" ]
then
    echo "ERROR: Missing d param"
    usage
    exit 1
fi
if [ ! "$BRAND_NAME" ]
then
    echo "ERROR: Missing b param"
    usage
    exit 1
fi

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

get_ansible_vars() {
	printer -t "Fetching ansible variables"

	if [ ! -d "${ANSIBLE_DIR}" ]; then
		source ${ENV_FILE}
		git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR}

		if [ ! $? -eq 0 ]; then
			printer -e "Failed to fetch variables"
		else
			printer -s "Fetched variables"
		fi
	else
		printer -n "Ansible variables present, skipping"
	fi
}

get_inventory() {
	printer -t "Downloading inventory file"

	scp -i ${AWS_CONDUCTOR_SSH_KEY_PATH} "${SCP_USER}"@"${CONDUCTOR_NODE_URL}":"${REMOTE_INVENTORY_PATH}" "${INVENTORY_PATH}"

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
		git clone --depth 1 --branch ${ANSIBLE_ROLE_VERSION} ${ANSIBLE_ROLE_INSTALL_URL} ${ANSIBLE_ROLE_INSTALL_PATH}

		# ansible-galaxy install ${ANSIBLE_ROLE_INSTALL_URL}
		if [ ! $? -eq 0 ]; then
			printer -e "Failed to install ansible role"
		else
			printer -s "Installed role"
		fi
	else
		printer -n "Ansible role present, skipping"
	fi
}

run_ansible() {
	printer -t "Executing Ansible Playbook"

	ansible-playbook --limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml

	[ ! $? -eq 0 ] && printer -e "Failed to execute ansible playbook"
}

configure_aws() {
	printer -n "Collecting credentials\n"

	aws configure

	if [ $? -eq 0 ]; then
		printer -s "Collected credentials"
	else
		printer -e "Failed to collect credentials"
	fi
}

create_directories() {
	printer -t "Creating project structure"

	mkdir -p ${KEYS_DIR}/distributionOwner \
		${KEYS_DIR}/lockupOwner \
		${CONTRACTS_DIR} \
		${VOLUMES_DIR}/volume1 \
		${VOLUMES_DIR}/volume2 \
		${VOLUMES_DIR}/volume3 \
		${VOLUMES_DIR}/volume4
			# ${ANSIBLE_DIR} \
		}

push_ansible_artifacts() {
	printer -t "Pushing Ansible artifacts"

	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -b ceremony-artifacts
	git -C ${ANSIBLE_DIR}/ add ${ANSIBLE_DIR}/
	git -C ${ANSIBLE_DIR}/ commit -m "Committing produced artifacts"
	git -C ${ANSIBLE_DIR}/ push origin HEAD --force &>> ${LOG_FILE}

	printer -s "Pushed ansible code to remote repo"
}

# All required params present, run the script.
printer -t "Starting key ceremony"

create_directories

# configure_aws

${SCRIPTS_DIR}/get_secrets.sh \
  $AWS_CONDUCTOR_SSH_KEY \
  $AWS_CONDUCTOR_SSH_KEY_PATH \
  $AWS_NODES_SSH_KEY \
  $AWS_NODES_SSH_KEY_PATH

get_ansible_vars
install_ansible_role
get_inventory

${SCRIPTS_DIR}/get_contract_bytecode.sh
${SCRIPTS_DIR}/create_lockup_owner_wallet.sh
${SCRIPTS_DIR}/create_distribution_owner_wallet.sh
${SCRIPTS_DIR}/create_distribution_issuer_wallet.sh
${SCRIPTS_DIR}/create_lockup_admin_wallet.sh

VALIDATOR_IPS=$(get_list_of_validator_ips)
${SCRIPTS_DIR}/create_validator_and_account_wallets.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_dao_storage.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_ansible_playbook2.sh -v "$VALIDATOR_IPS"
# cp -r ${KEYS_DIR} ${ANSIBLE_DIR}/
run_ansible &
wait

push_ansible_artifacts

# Copy sensitive things to the volumes
for volume in $VOLUMES_DIR/*/ ; do
    for count in 1 2
    do
        ${SCRIPTS_DIR}/copy_keys_to_volume.sh $DESTINATION_DIR $volume
    done
done

${SCRIPTS_DIR}/finished.sh

