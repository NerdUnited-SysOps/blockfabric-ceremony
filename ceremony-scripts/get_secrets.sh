#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Path to .env file"
	echo "  -h : This help message"
}

while getopts e:h option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} ${SCRIPTS_DIR}/printer.sh file doesn't exist" && exit 1
	${SCRIPTS_DIR}/printer.sh "$@"
}

[[ -z "${AWS_PRIMARY_PROFILE}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_PRIMARY_PROFILE" && exit 1
[[ -z "${AWS_CONDUCTOR_SSH_KEY}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_CONDUCTOR_SSH_KEY" && exit 1
[[ -z "${AWS_CONDUCTOR_SSH_KEY_PATH}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_CONDUCTOR_SSH_KEY_PATH" && exit 1
[[ -z "${AWS_NODES_SSH_KEY}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_NODES_SSH_KEY" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH" && exit 1
[[ -z "${AWS_GITHUB_CEREMONY_PAT}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing AWS_GITHUB_CEREMONY_PAT" && exit 1

get_key() {
	secret_id=$1

	if [ -n "${secret_id}" ]; then
		aws secretsmanager \
			get-secret-value \
			--secret-id "${secret_id}" \
			--output text \
			--profile ${AWS_PRIMARY_PROFILE} \
			--query SecretString
	else
		printer -e "Missing secret key id."
	fi
}

write_key() {
	value=$1
	file_path=$2

	if [ -n "${value}" ] && [ -n "${file_path}" ]; then
		echo -e "${value}" > "${file_path}"
		chmod 0600 "${file_path}"

		printer -s "Wrote to ${file_path}."
	else
		printer -e "Missing value to write to file: ${file_path}."
	fi
}

set_env_var() {
	VAR_NAME=$1
	VAR_VAL=$2
	FILE_NAME=$ENV_FILE

	if [ -n "${VAR_VAL}" ]; then
		if grep -q "export ${VAR_NAME}" "${FILE_NAME}"
		then
			sed -i "s/^export ${VAR_NAME}=.*/export ${VAR_NAME}=${VAR_VAL}/g" "${FILE_NAME}"
		else
			sed -i "1iexport ${VAR_NAME}=${VAR_VAL}" "${FILE_NAME}"
		fi
		printer -s "Persisted ${VAR_NAME}."
	else
		printer -e "Missing ${VAR_NAME}"
	fi
}

printer -t "Retrieving secrets"

KEY1=$(get_key "${AWS_CONDUCTOR_SSH_KEY}")
write_key "${KEY1}" "${AWS_CONDUCTOR_SSH_KEY_PATH}"

KEY2=$(get_key "${AWS_NODES_SSH_KEY}")
write_key "${KEY2}" "${AWS_NODES_SSH_KEY_PATH}"

GITHUB_PAT=$(get_key "${AWS_GITHUB_CEREMONY_PAT}")
set_env_var "GITHUB_PAT" "${GITHUB_PAT}"

