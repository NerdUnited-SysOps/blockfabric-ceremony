#!/bin/bash

# Helper function to download files from AWS Secrets Manager
# We'll have an SSH key inside AWS Secrets Manager to be used by Ansible
# Example call: download_file_from_aws "my-secret-aws-key" "../privatekey.pem"
# Use `aws secretsmanager create-secret --name $SECRET_ID --secret-binary fileb://../test_secret_file.txt` to create a test file.

echo "Retrieving secrets"

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

SECRET_ID=$1
LOCAL_FILE=$2

aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --query SecretBinary --output text | base64 --decode > ${LOCAL_FILE}

if [ -f "${LOCAL_FILE}" ]; then
    echo "${LOCAL_FILE} exists."
    chmod 0600 ${SSH_KEY_DOWNLOAD_PATH}
else 
    echo "${LOCAL_FILE} does not exist."
    exit 1
fi
