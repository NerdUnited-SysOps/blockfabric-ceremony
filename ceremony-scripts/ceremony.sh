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
    ansible validator --list-hosts -i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_list_of_rpc_ips () {
    ansible rpc --list-hosts -i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
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

# All required params present, run the script.
${SCRIPTS_DIR}/print_title.sh "Starting key ceremony"

${SCRIPTS_DIR}/create_directories.sh
${SCRIPTS_DIR}/install_dependencies.sh

echo -e "\nVerify credentials\n"

aws configure

${SCRIPTS_DIR}/get_secrets.sh \
  $AWS_CONDUCTOR_SSH_KEY \
  $AWS_CONDUCTOR_SSH_KEY_PATH \
  $AWS_NODES_SSH_KEY \
  $AWS_NODES_SSH_KEY_PATH

${SCRIPTS_DIR}/get_inventory.sh ${SCP_USER} ${CONDUCTOR_NODE_URL} ${REMOTE_INVENTORY_PATH} ${INVENTORY_PATH}

VALIDATOR_IPS=$(get_list_of_validator_ips)
RPC_IPS=$(get_list_of_rpc_ips)

${SCRIPTS_DIR}/get_contract_bytecode.sh
${SCRIPTS_DIR}/create_lockup_owner_wallet.sh
${SCRIPTS_DIR}/create_distribution_owner_wallet.sh
${SCRIPTS_DIR}/create_distribution_issuer_wallet.sh
${SCRIPTS_DIR}/create_lockup_admin_wallet.sh
${SCRIPTS_DIR}/create_validator_and_account_wallets.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_dao_storage.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_ansible_goquorum_playbook.sh -v "$VALIDATOR_IPS" -r "$RPC_IPS"
${SCRIPTS_DIR}/install_ansible_role.sh
${SCRIPTS_DIR}/get_ansible_vars.sh
${SCRIPTS_DIR}/run_ansible_playbook.sh
${SCRIPTS_DIR}/push_ansible_artifacts.sh

# Move sensitive things to the volumes
for volume in *../volumes ; do
    for count in 1 2
    do 
        ${SCRIPTS_DIR}/move_keys_to_volume.sh $DESTINATION_DIR $volume 
    done
done

${SCRIPTS_DIR}/finished.sh

