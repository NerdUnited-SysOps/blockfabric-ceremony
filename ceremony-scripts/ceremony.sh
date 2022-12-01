#!/bin/bash
# Script `ceremony`

# TODO: (Need to haves)
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Make sure you can support and test with 2 copies of each volume

# put the github API key inside the secrets manager
# Retrieve github API token from secrets manager
# Pull in brand specific variables for network (chainid, brand name, etc)
# Push all the brand ansible back to repo
# Add chmod to the id_rsa key
# Add the public key that corresponds to the private key that we pull down from secrets mgr into the conductor and all the nodes, val1, val2, rpc in the authorized user
# Find out names for variables to be kept in the secrets manager

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
${SCRIPTS_DIR}/create_distribution_issuer_wallet.sh
${SCRIPTS_DIR}/create_lockup_admin_wallet.sh
${SCRIPTS_DIR}/create_validator_and_account_wallets.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate_dao_storage.sh "$VALIDATOR_IPS"
${SCRIPTS_DIR}/generate-ansible-goquorum-playbook.sh -v "$VALIDATOR_IPS" -r "$RPC_IPS"
${SCRIPTS_DIR}/install_ansible_role.sh
${SCRIPTS_DIR}/run_ansible_playbook.sh

# Move sensitive things to the volumes
for volume in *../volumes ; do
    for count in 1 2
    do 
        ${SCRIPTS_DIR}/move_keys_to_volume.sh $DESTINATION_DIR $volume 
    done
done

${SCRIPTS_DIR}/finished.sh

