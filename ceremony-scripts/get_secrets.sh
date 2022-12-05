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

KEY=$(aws secretsmanager \
	get-secret-value \
	--secret-id ${AWS_CONDUCTOR_SSH_KEY} \
	--output text \
	--query SecretString | jq .private_key | tr -d '"')
echo ${KEY}

if [ -n "${KEY}" ]; then
	echo -e ${KEY} > ${LOCAL_FILE1}
	chmod 0600 ${LOCAL_FILE1}

	${SCRIPTS_DIR}/printer.sh -s "Retrieved ${AWS_CONDUCTOR_SSH_KEY_PATH}."
else 
	${SCRIPTS_DIR}/printer.sh -e "${LOCAL_FILE1} does not exist."
fi

set_env_var() {
	VAR_NAME=$1
	VAR_VAL=$2
	FILE_NAME=$ENV_FILE

	if grep -q "export ${VAR_NAME}" "${FILE_NAME}"
	then
		sed -i "s/^export ${VAR_NAME}=.*/export ${VAR_NAME}=${VAR_VAL}/g" "${FILE_NAME}"
	else
		sed -i "1iexport ${VAR_NAME}=${VAR_VAL}" "${FILE_NAME}"
	fi
}

LOCAL_SYSOPS_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id ${AWS_GITHUB_SYSOPS_TOKEN_NAME} \
    --output text \
    --query SecretString)

if [ -n "${LOCAL_SYSOPS_TOKEN}" ]; then
   ${SCRIPTS_DIR}/printer.sh -s "Retrieved sysops pat"
	 set_env_var "GITHUB_SYSOPS_TOKEN" "${LOCAL_SYSOPS_TOKEN}"
else
   ${SCRIPTS_DIR}/printer.sh -e "Failed to retrieve sysops pat"
fi

LOCAL_CORESDK_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id ${AWS_GITHUB_CORESDK_TOKEN_NAME} \
    --output text \
    --query SecretString)

if [ -n "${LOCAL_CORESDK_TOKEN}" ]; then
   ${SCRIPTS_DIR}/printer.sh -s "Retrieved coresdk pat"
	 set_env_var "GITHUB_CORESDK_TOKEN" "${LOCAL_CORESDK_TOKEN}"
else
   ${SCRIPTS_DIR}/printer.sh -e "Failed to retrieve pat"
fi

