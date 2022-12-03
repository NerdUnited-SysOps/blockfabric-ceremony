#!/bin/bash

set -e

# Helper function to download files from AWS Secrets Manager
# We'll have an SSH key inside AWS Secrets Manager to be used by Ansible
# Example call: download_file_from_aws "my-secret-aws-key" "../privatekey.pem"
# Use `aws secretsmanager create-secret --name $SECRET_ID --secret-binary fileb://../test_secret_file.txt` to create a test file.

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Retrieving secrets"

SECRET_ID1=${1:-$AWS_CONDUCTOR_SSH_KEY}
LOCAL_FILE1=${2:-$AWS_CONDUCTOR_SSH_KEY_PATH}

SECRET_ID2=${3:-$AWS_NODES_SSH_KEY}
LOCAL_FILE2=${4:-$AWS_NODES_SSH_KEY_PATH}

aws secretsmanager get-secret-value --secret-id ${SECRET_ID1} --query SecretBinary --output text | base64 --decode > ${LOCAL_FILE1}

if [ -f "${LOCAL_FILE1}" ]; then
    ${SCRIPTS_DIR}/printer.sh -s "Retrieved ${LOCAL_FILE1}."
    chmod 0600 ${LOCAL_FILE1}
else 
    ${SCRIPTS_DIR}/printer.sh -e "${LOCAL_FILE1} does not exist."
fi

aws secretsmanager \
    get-secret-value \
    --secret-id ${SECRET_ID2} \
    --query SecretBinary \
    --output text | base64 --decode > ${LOCAL_FILE2}

if [ -f "${LOCAL_FILE2}" ]; then
    ${SCRIPTS_DIR}/printer.sh -s "Retrieved ${LOCAL_FILE2}."
    chmod 0600 ${LOCAL_FILE2}
else 
    ${SCRIPTS_DIR}/print_error.sh "${LOCAL_FILE2} does not exist."
fi

set_env_var() {
	VAR_NAME=$1
	VAR_VAL=$2
	FILE_NAME=$ENV_FILE

	if grep -q "${VAR_NAME}" "${FILE_NAME}"
	then
		sed -i "s/^export ${VAR_NAME}=.*/export ${VAR_NAME}=${VAR_VAL}/g" "${FILE_NAME}"
	else
		echo "export ${VAR_NAME}=${VAR_VAL}" >> "${FILE_NAME}"
	fi
}

LOCAL_SYSOPS_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id ${AWS_GITHUB_SYSOPS_TOKEN_NAME} \
    --output text \
    --query SecretString)

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to retrieve sysops github token"
fi

set_env_var "GITHUB_SYSOPS_TOKEN" "${LOCAL_SYSOPS_TOKEN}"
# echo "export GITHUB_SYSOPS_TOKEN=${LOCAL_SYSOPS_TOKEN}" >> ${ENV_FILE}

LOCAL_CORESDK_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id ${AWS_GITHUB_CORESDK_TOKEN_NAME} \
    --output text \
    --query SecretString)

if [ ! $? -eq 0 ]; then
   ${SCRIPTS_DIR}/printer.sh -e "Failed to retrieve coresdk github token"
fi

	# echo "export GITHUB_CORESDK_TOKEN=${LOCAL_CORESDK_TOKEN}" >> ${ENV_FILE}
set_env_var "GITHUB_CORESDK_TOKEN" "${LOCAL_CORESDK_TOKEN}"

