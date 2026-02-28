#!/usr/bin/env zsh

set -e

SECONDS=0

usage() {
	echo "This script generates Besu node keys, tears down, and redeploys the QBFT network."
	echo "Usage: $0 (options) ..."
	echo "  -e : Path to .env file"
	echo "  -d : Dev/debug mode (passed by ceremony.sh)"
	echo "  -v : Enable verbose Ansible output on console"
	echo "  -h : Help"
	echo ""
	echo "Example: $0 -e lace-testnet.env"
}

while getopts 'de:hv' option; do
	case "$option" in
		d) ;;  # dev mode flag — no action needed here
		e)
			ENV_FILE=${OPTARG}
			;;
		v)
			VERBOSE_FLAG="-v"
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

if [ ! -f "${ENV_FILE}" ]; then
	echo "Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR is not a directory: ${SCRIPTS_DIR}" && exit 1

[[ -z "${LOG_FILE}" ]] && echo ".env is missing LOG_FILE variable" && exit 1
[[ -z "${INVENTORY_PATH}" ]] && echo ".env is missing INVENTORY_PATH variable" && exit 1
[[ ! -f "${INVENTORY_PATH}" ]] && echo "Inventory not found: ${INVENTORY_PATH}" && exit 1
[[ -z "${ANSIBLE_ROLE_DIR}" ]] && echo ".env is missing ANSIBLE_ROLE_DIR variable" && exit 1
[[ ! -d "${ANSIBLE_ROLE_DIR}" ]] && echo "ANSIBLE_ROLE_DIR is not a directory: ${ANSIBLE_ROLE_DIR}" && exit 1

source "${SCRIPTS_DIR}/ansible_helpers.sh"

printer() {
	if [[ -f "${SCRIPTS_DIR}/printer.sh" ]]; then
		${SCRIPTS_DIR}/printer.sh "$@"
	else
		echo "$@"
	fi
}

# ── 1. Teardown existing deployment ──────────────────────────────────
printer -t "Tearing down existing Besu deployment"

ANSIBLE_HOST_KEY_CHECKING=False \
ANSIBLE_FORCE_COLOR=True \
ANSIBLE_ROLES_PATH="${ANSIBLE_ROLE_DIR}/..:${HOME}/.ansible/roles" \
    run_ansible_logged "${LOG_FILE}" \
    -e "ansible_ssh_private_key_file=${AWS_NODES_SSH_KEY_PATH}" \
    -i "${INVENTORY_PATH}" \
    "${ANSIBLE_ROLE_DIR}/test/teardown.yml"

printer -s "Teardown complete"

# ── 2. Deploy fresh network ──────────────────────────────────────────
printer -t "Deploying Besu QBFT network"

ANSIBLE_HOST_KEY_CHECKING=False \
ANSIBLE_FORCE_COLOR=True \
ANSIBLE_ROLES_PATH="${ANSIBLE_ROLE_DIR}/..:${HOME}/.ansible/roles" \
    run_ansible_logged "${LOG_FILE}" \
    -e "ansible_ssh_private_key_file=${AWS_NODES_SSH_KEY_PATH}" \
    -i "${INVENTORY_PATH}" \
    "${ANSIBLE_ROLE_DIR}/test/validate.yml"

duration=$SECONDS
printer -s "Deployment completed in $(($duration / 60)) minutes $(($duration % 60)) seconds"

printer -f 40
