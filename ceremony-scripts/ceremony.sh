#!/bin/bash
# Script `ceremony`

usage() {
  echo "This script sets up the validator nodes..."
  echo "Usage: $0 (options) ..."
  echo "  -d : Data directory on external volume"
  echo "  -h : Help"
  echo "  -i : String of space separated IP addresses for Validator nodes."
  echo ""
  echo "Example: "
}

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
    else 
        echo "$LOCAL_FILE does not exist."
        exit 1
    fi
}

install_dependencies () {
    sudo apt-get update # Probably put a specific version on all of these
    sudo apt-get install -y awscli pwgen jq golang
    go install github.com/ethereum/go-ethereum/cmd/ethkey@v1.10.26
    go install github.com/ethereum/go-ethereum/cmd/geth@v1.10.26
    export PATH="${HOME}/go/bin:${PATH}"

    aws configure
}

setup_validator_nodes () {
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
        sed  -n "s/Private\skey:\s*\(.*\)/\1/p"  nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey
        sed  -n "s/Public\skey:\s*04\(.*\)/\1/p" nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey_pub
        sed  -n "s/Address:\s*\(.*\)/\1/p"       nodekey_contents | tr -d '\n' > ${WORKING_DIR}/nodekey_address
        echo -n "0x$(cat ${WORKING_DIR}/account_ks | jq -r ".address" | tr -d '\n')" > ${WORKING_DIR}/account_address

        # Delete the pw file. We required a file with
        rm -rf ${WORKING_DIR}/pw

        mv nodekey_contents ${WORKING_DIR}/nodekey_contents
    done
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



while getopts 'c:d:i:h' option; do
  case "$option" in
    d)
        DESTINATION_DIR="${OPTARG}"
        ;;
    i)
        IP_ADDRESS_LIST="${OPTARG}"
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

# For simplicity, let's use this same Key in AWS Secrets Mgr for retrieving the SSH Key.
AWS_SSH_KEY_SECRET_ID="ssh-key-secret"
SSH_KEY_DOWNLOAD_PATH="../privatekey.pem"

# validate required params
if [ ! "$DESTINATION_DIR" ] || [ ! "$IP_ADDRESS_LIST" ] \
    || [ ! "$AWS_SSH_KEY_SECRET_ID" ] || [ ! "$SSH_KEY_DOWNLOAD_PATH" ]
then
    echo "Required params missing" 
    usage
    exit 1
fi

# All required params present, run the script.
echo "Starting key ceremony"
install_dependencies
download_file_from_aws $AWS_SSH_KEY_SECRET_ID $SSH_KEY_DOWNLOAD_PATH
# TODO
# grab the inventory file
# make the list of nodes an input into the rest of the script
setup_validator_nodes
create_lockup_owner_wallet
create_distribution_owner_wallet
echo "Key ceremony complete"

