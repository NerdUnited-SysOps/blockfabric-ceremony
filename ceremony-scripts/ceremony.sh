#!/bin/bash
# Script `ceremony`

# TODO: (Need to haves)
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Make sure you can support and test with 2 copies of each volume
# Push distribution issuer private key to Secrets Manager
# put the github API key inside the secrets manager
# Retrieve github API token from secrets manager
# install the role from ansible-galaxy (using the github token)
# execute the playbook against all nodes in the inventory
# Pull in brand specific variables for network (chainid, brand name, etc)

# TODO: (Nice to haves)
# Create templates of all the ansible artifacts (genesis.json, brand vars, etc)
# Push those template files to a brand repo.
# consistent formatting
# sensible error checking
# standardize individual scripts
# * Standardized inputs
# * Standardized output
# * All output redirected to logs
# Implement a verbose mode to output to logs and stdout
# Verification step in code

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

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $BASE_DIR/../.common.sh

get_list_of_validator_ips () {
    ansible validator --list-hosts -i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_list_of_rpc_ips () {
    ansible rpc --list-hosts -i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

download_ansible_role() {
    mkdir -p ~/ansible/roles/
    git clone git@github.com:NerdUnited-Nerd/ansible-role-lace.git ~/ansible/roles/ansible-role-lace
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
if [ ! "$AWS_SSH_KEY_SECRET_ID" ]
then
    echo "ERROR: Missing aws ssh key secret id"
    usage
    exit 1
fi
if [ ! "$SSH_KEY_DOWNLOAD_PATH" ]
then
    echo "ERROR: Missing ssh key download path"
    usage
    exit 1
fi

# All required params present, run the script.
echo "Starting key ceremony"

${SCRIPTS_DIR}/create_directories.sh
${SCRIPTS_DIR}/install_dependencies.sh
aws configure
${SCRIPTS_DIR}/get_secrets.sh $AWS_SSH_KEY_SECRET_ID $SSH_KEY_DOWNLOAD_PATH
${SCRIPTS_DIR}/get_inventory.sh ${SCP_USER} ${CONDUCTOR_NODE_URL} /opt/blockfabric/inventory ${INVENTORY_PATH}

VALIDATOR_IPS=$(get_list_of_validator_ips)
RPC_IPS=$(get_list_of_rpc_ips)

${SCRIPTS_DIR}/get_contract_bytecode.sh
${SCRIPTS_DIR}/create_lockup_owner_wallet.sh
${SCRIPTS_DIR}/create_distribution_owner_wallet.sh
${SCRIPTS_DIR}/create_validator_and_account_wallets.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_dao_storage.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate-ansible-goquorum-playbook.sh -v "$VALIDATOR_IPS" -r "$RPC_IPS"
${SCRIPTS_DIR}/install_ansible_role.sh
${SCRIPTS_DIR}/run_ansible_playbook.sh

${SCRIPTS_DIR}/finished.sh

