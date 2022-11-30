#!/bin/bash
# Script `ceremony`

# TODO:
# ✅ Create an env file with all the environment variables
# ✅ Create env file with overrides
# ✅ Pull in validator DAO smart contract bytecode v0.0.1
# ✅ Pull in bytecode for Lockup and Distribution contracts v0.1.0
# ✅ Get bin-runtime added to the distribution and lockup contract releases
# stoarge.txt generation
# * Pull down the validator DAO contract
# * install npm and javascript
# * pull in the JS (createContent.js) for generating the storage.txt
# * generate the allowlist.txt with the account and nodekeys
# * Generate storage.txt with createContent.js
# Move the keys to the appropriate locations
# ✅ We need to know where to put the passwords for the keystore files
# Format the volumes
# Push the keys to the volumes (with output of where they're going to the console)
# Push distribution issuer private key to Secrets Manager
# Pin dependency versions
# Clone specific tag of dao contract
# Break functions out into individual scripts
# put the github API key inside the secrets manager
# Retrieve github API token from secrets manager
# install the role from ansible-galaxy
# generate the ansible playbook
# execute the playbook against all nodes in the inventory

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

# For simplicity, let's use this same Key in AWS Secrets Mgr for retrieving the SSH Key.
AWS_SSH_KEY_SECRET_ID="conductor-key-test"
SSH_KEY_DOWNLOAD_PATH="../id_rsa"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh


# Helper function to download files from AWS Secrets Manager
# We'll have an SSH key inside AWS Secrets Manager to be used by Ansible
# Example call: download_file_from_aws "my-secret-aws-key" "../privatekey.pem"
# Use `aws secretsmanager create-secret --name $SECRET_ID --secret-binary fileb://../test_secret_file.txt` to create a test file.
download_file_from_aws () {
    SECRET_ID=$1
    LOCAL_FILE=$2
    
    aws secretsmanager get-secret-value --secret-id $SECRET_ID --query SecretBinary --output text | base64 --decode > $LOCAL_FILE

    if [ -f "$LOCAL_FILE" ]; then
        echo "$LOCAL_FILE exists."
	chmod 0600 $SSH_KEY_DOWNLOAD_PATH
    else 
        echo "$LOCAL_FILE does not exist."
        exit 1
    fi
}

# Downloads via scp an inventory file containing ip address list of nodes
# Params:
#   user - user to ssh into box
#   host - host to pull file from
#   file - file to scp
# Example call: download_inventory_file "user" "152.167.123.1" "inventory_file.txt" "../ceremony_scripts/"
download_inventory_file () {
    user=$1
    host=$2
    file=$3
    local_file=$4
    scp -i $SSH_KEY_DOWNLOAD_PATH "$user"@"$host":"$file" "$local_file"

    if [ -f "$local_file" ]; then
        echo "$local_file exists."
    else 
        echo "$local_file does not exist."
        exit 1
    fi
}

get_list_of_ips () {
    ansible all_quorum --list-hosts -i ./inventory | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_list_of_validator_ips () {
    ansible validator --list-hosts -i ./inventory | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

get_list_of_rpc_ips () {
    ansible rpc --list-hosts -i ./inventory | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}

create_key_directories() {
    mkdir -p ${KEYS_DIR}/distributionOwner \
	    ${KEYS_DIR}/lockupOwner \
	    ${CONTRACTS_DIR} \
	    ${VOLUMES_DIR}/volume1 \
	    ${VOLUMES_DIR}/volume2 \
	    ${VOLUMES_DIR}/volume3 \
	    ${VOLUMES_DIR}/volume4
}

setup_validator_nodes () {
    IP_ADDRESS_LIST=$1
    echo "IP_ADDRESS_LIST"
    for ip in ${IP_ADDRESS_LIST}
    do
        echo "Setting up validator node for ip: ${ip}"
        mkdir -p "${DESTINATION_DIR}"/$ip
        WORKING_DIR=${DESTINATION_DIR}/$ip

        password=$(pwgen -c 25 -n 1)
        echo $password > ${WORKING_DIR}/pw
        # TODO - Find another way to use ethkey inspect without using a password file.
        PASSWORD_FILE=${WORKING_DIR}/pw

        # Setup node wallet
        geth account new --password <(echo -n "$password") --keystore ${DESTINATION_DIR}
        mv ${DESTINATION_DIR}/UTC* ${WORKING_DIR}/nodekey_ks

        node_key_address=$(cat "${WORKING_DIR}"/nodekey_ks | jq -r ".address" | tr -d '\n')
        aws secretsmanager create-secret --name "$node_key_address" --description "Encryption pw for 0x$node_key_address." --secret-string "$password"

        # Setup account wallet
        geth account new --password <(echo -n "$password") --keystore ${DESTINATION_DIR}
        mv ${DESTINATION_DIR}/UTC* ${WORKING_DIR}/account_ks
        account_address=$(cat "${WORKING_DIR}"/account_ks | jq -r ".address" | tr -d '\n')
        aws secretsmanager create-secret --name "$account_address" --description "Encryption pw for 0x$account_address." --secret-string "$password"

        # Create key file
        nodekey_ks=${WORKING_DIR}/nodekey_ks
        # This requires a password file.
        ethkey inspect --private --passwordfile $PASSWORD_FILE $nodekey_ks > nodekey_contents 
        sed  -n "s/Private\skey:\s*\(.*\)/\1/p"  nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey
        sed  -n "s/Public\skey:\s*04\(.*\)/\1/p" nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey_pub
        sed  -n "s/Address:\s*\(.*\)/\1/p"       nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey_address
        echo -n "0x$(cat ${WORKING_DIR}/account_ks | jq -r ".address" | tr -d '\n')" > ${WORKING_DIR}/account_address

        # Delete the pw file. We required a file with
        rm -rf ${WORKING_DIR}/pw

        mv nodekey_contents ${WORKING_DIR}/nodekey_contents
    done
}

#- name: Build dao allowed accounts for storage section
#if: (env.TF_ACTION_TYPE == 'apply' && github.event_name  == 'push')
## TODO: Can cache the DAO allowed accounts list until the version changes
#run: |
#  [ -d $(dirname $DAO_CONTRACT_ARCHIVE_DIR) ] || mkdir -p $(dirname $DAO_CONTRACT_ARCHIVE_DIR)
#  echo -n > $ALLOWED_ACCOUNTS_FILE
#  while read ip; do
#    ACCOUNT_ADDRESS=$(cat ansible/keys/$ip/account_address | tr -d '\n')
#    NODEKEY_ADDRESS=$(cat ansible/keys/$ip/nodekey_address | tr -d '\n')
#    echo "$ACCOUNT_ADDRESS, $NODEKEY_ADDRESS" >> $ALLOWED_ACCOUNTS_FILE
#  done < $VALIDATOR_IPS_FILE
#env:
#  ALLOWED_ACCOUNTS_FILE: ansible/contracts/sc_dao/allowedAccountsAndValidators.txt
#  VALIDATOR_IPS_FILE: ansible/validator_ips.txt
#  DAO_CONTRACT_ARCHIVE_DIR: ansible/contracts/sc_dao

clone_dao() {
    mkdir -p ~/sc_dao
    git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/NerdCoreSdk/sc_dao.git ~/sc_dao
}

create_lockup_owner_wallet () {
    mkdir -p ${DESTINATION_DIR}/lockupOwner
    WORKING_DIR=${DESTINATION_DIR}/lockupOwner

    password=$(pwgen -c 25 -n 1)

    geth account new --password <(echo -n "$password") --keystore ${DESTINATION_DIR}
    mv ${DESTINATION_DIR}/UTC* ${WORKING_DIR}/ks
    address=$(cat ${WORKING_DIR}/ks | jq -r ".address" | tr -d '\n')
    echo -n "Node key address: $address"
    aws secretsmanager create-secret --name "$address" --description "Encryption pw for 0x$address." --secret-string "$password"
    
    # Extract address from keystore file, insert into new address file
    echo -n "$(cat ${WORKING_DIR}/ks | jq -r ".address" | tr -d '\n')" > ${WORKING_DIR}/address
}

create_distribution_owner_wallet () {
    mkdir -p ${DESTINATION_DIR}/distributionOwner
    WORKING_DIR=${DESTINATION_DIR}/distributionOwner

    password=$(pwgen -c 25 -n 1)

    geth account new --password <(echo -n "$password") --keystore ${DESTINATION_DIR}
    mv ${DESTINATION_DIR}/UTC* ${WORKING_DIR}/ks
    address=$(cat ${WORKING_DIR}/ks | jq -r ".address" | tr -d '\n')
    echo -n "Node key address: $address"
    aws secretsmanager create-secret --name "$address" --description "Encryption pw for 0x$address." --secret-string "$password"

    # Extract address from keystore file, insert into new address file
    echo -n "$(cat ${WORKING_DIR}/ks | jq -r ".address" | tr -d '\n')" > ${WORKING_DIR}/address
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

${SCRIPTS_DIR}/install_dependencies.sh
aws configure
download_file_from_aws $AWS_SSH_KEY_SECRET_ID $SSH_KEY_DOWNLOAD_PATH
download_inventory_file ${SCP_USER} ${CONDUCTOR_NODE_URL} /opt/blockfabric/inventory ./inventory
IP_LIST=$(get_list_of_ips)
VALIDATOR_IPS=$(get_list_of_validator_ips)
RPC_IPS=$(get_list_of_rpc_ips)

create_key_directories

./get_contract_bytecode.sh
setup_validator_nodes "$IP_LIST"
create_lockup_owner_wallet
create_distribution_owner_wallet
./scripts/generate-ansible-goquorum-playbook.sh -v "$VALIDATOR_IPS" -r "$RPC_IPS"
echo "Key ceremony complete"

