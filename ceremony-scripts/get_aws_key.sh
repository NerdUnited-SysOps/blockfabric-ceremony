#!/usr/bin/env zsh

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
ENV_FILE="${SCRIPTS_DIR}/../.env"

usage() {
	echo "Options"
	echo "  -e : Path to .env file"
	echo "  -h : This help message"
	echo "  -s : Script directory to reference other scripts"
}

while getopts e:f:g:hl:s: option; do
	case "${option}" in
		f)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		s)
			SCRIPTS_DIR=${OPTARG}
			;;
	esac
done

source ${ENV_FILE}

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

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
