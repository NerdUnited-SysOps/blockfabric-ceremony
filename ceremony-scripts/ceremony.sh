#!/bin/bash
# Script `ceremony`

# TODO: (Need to haves)
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Make sure you can support and test with 2 copies of each volume

# Pull in brand specific variables for network (chainid, brand name, etc)
# Find out names for variables to be kept in the secrets manager

# TODO: (Nice to haves)
# Create templates of all the ansible artifacts (genesis.json, brand vars, etc)
# consistent formatting
# sensible error checking
# standardize individual scripts
# * Standardized inputs
# * Standardized output
# * All output redirected to logs
# Implement a verbose mode to output to logs and stdout
# Verification step in code
# (for vagrant dev) Add the public key that corresponds to the private key that we pull down from secrets mgr into the conductor and all the nodes, val1, val2, rpc in the authorized user

set -e

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -b : Brand name"
  echo "  -d : Data directory on external volume"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

while getopts 'b:d:h' option; do
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
    ?)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

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

get_ansible_vars() {
	${SCRIPTS_DIR}/printer.sh -t "Fetching ansible variables"

	if [ ! -d "${ANSIBLE_DIR}" ]; then
		git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR}

		if [ ! $? -eq 0 ]; then
			${SCRIPTS_DIR}/printer.sh -e "Failed to fetch variables"
		else
			${SCRIPTS_DIR}/printer.sh -s "Fetched variables"
		fi
	else
		${SCRIPTS_DIR}/printer.sh -n "Ansible variables present, skipping"
	fi
}

get_inventory() {
	${SCRIPTS_DIR}/printer.sh -t "Downloading inventory file"

	scp -i ${AWS_CONDUCTOR_SSH_KEY_PATH} "${SCP_USER}"@"${CONDUCTOR_NODE_URL}":"${REMOTE_INVENTORY_PATH}" "${INVENTORY_PATH}"

	if [ -n "${$?}" ] && [ -f "$INVENTORY_PATH" ]; then
		${SCRIPTS_DIR}/printer.sh -s "$INVENTORY_PATH exists."
	else 
		${SCRIPTS_DIR}/printer.sh -e "Failed to retrieve ${local_file}"
	fi
}

install_ansible_role() {
	${SCRIPTS_DIR}/printer.sh -t "Installing Ansible role"

	if [ ! -f "${ANSIBLE_ROLE_INSTALL_PATH}" ]; then
		ansible-galaxy install ${ANSIBLE_ROLE_INSTALL_URL}
		if [ ! $? -eq 0 ]; then
			${SCRIPTS_DIR}/printer.sh -e "Failed to install ansible role"
		else
			${SCRIPTS_DIR}/printer.sh -s "Installed role"
		fi
	else
		${SCRIPTS_DIR}/printer.sh -n "Ansible role present, skipping"
	fi
}

run_ansible() {
	${SCRIPTS_DIR}/printer.sh -t "Executing Ansible Playbook"

	ansible-playbook --limit all_quorum -i ${INVENTORY_PATH} ${ANSIBLE_DIR}/goquorum.yaml --private-key=${AWS_NODES_SSH_KEY_PATH}

	[ ! $? -eq 0 ] && ${SCRIPTS_DIR}/printer.sh -e "Failed to execute ansible playbook"
}

configure_aws() {
	${SCRIPTS_DIR}/printer.sh -n "Collecting credentials\n"

	aws configure

	if [ $? -eq 0 ]; then
		${SCRIPTS_DIR}/printer.sh -s "Collected credentials"
	else
		${SCRIPTS_DIR}/printer.sh -e "Failed to collect credentials"
	fi
}

create_directories() {
	${SCRIPTS_DIR}/printer.sh -t "Creating project structure"

	mkdir -p ${KEYS_DIR}/distributionOwner \
		${KEYS_DIR}/lockupOwner \
		${CONTRACTS_DIR} \
		${VOLUMES_DIR}/volume1 \
		${VOLUMES_DIR}/volume2 \
		${VOLUMES_DIR}/volume3 \
		${VOLUMES_DIR}/volume4
			# ${ANSIBLE_DIR} \
		}

# All required params present, run the script.
${SCRIPTS_DIR}/printer.sh -t "Starting key ceremony"

create_directories
# ${SCRIPTS_DIR}/install_dependencies.sh

configure_aws

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
cp -r ${KEYS_DIR} ${ANSIBLE_DIR}/
run_ansible
${SCRIPTS_DIR}/push_ansible_artifacts.sh

# Move sensitive things to the volumes
for volume in $VOLUMES_DIR/*/ ; do
    for count in 1 2
    do 
        ${SCRIPTS_DIR}/move_keys_to_volume.sh $DESTINATION_DIR $volume 
    done
done

${SCRIPTS_DIR}/finished.sh

