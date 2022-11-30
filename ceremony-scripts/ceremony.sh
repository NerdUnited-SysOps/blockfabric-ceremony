#!/bin/bash
# Script `ceremony`

# TODO:
# ✅ Create an env file with all the environment variables
# ✅ Create env file with overrides
# ✅ Pull in validator DAO smart contract bytecode v0.0.1
# ✅ Pull in bytecode for Lockup and Distribution contracts v0.1.0
# ✅ Get bin-runtime added to the distribution and lockup contract releases
# ✅ stoarge.txt generation
# ✅ * Clone specific tag of dao contract
# ✅ * Pull down the validator DAO contract
# ✅ * install npm and javascript
# ✅ * pull in the JS (createContent.js) for generating the storage.txt
# ✅ * generate the allowlist.txt with the account and nodekeys
# ✅ * Generate storage.txt with createContent.js
# ✅ Move the keys to the appropriate locations
# ✅ We need to know where to put the passwords for the keystore files
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Push distribution issuer private key to Secrets Manager
# ✅ Pin dependency versions
# ✅ Break functions out into individual scripts
# put the github API key inside the secrets manager
# Retrieve github API token from secrets manager
# install the role from ansible-galaxy
# generate the ansible playbook
# execute the playbook against all nodes in the inventory
# consistent formatting
# sensible error checking
# standardize individual scripts

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
source .common.sh

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

${SCRIPTS_DIR}/finished.sh

