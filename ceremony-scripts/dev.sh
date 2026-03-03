#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -o : Option number for non-interactive selection"
	echo "  -d : Dev menu (passed by ceremony.sh)"
	echo "  -v : Enable verbose Ansible output on console"
	echo "  --besu : Use Besu reset and ansible playbooks"
	echo "  -h : This help message"
}

# Pre-process --besu flag (getopts doesn't support long options)
args=()
for arg in "$@"; do
    case "$arg" in
        --besu) BESU_MODE=true ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

while getopts de:ho:v option; do
	case "${option}" in
		d) ;;  # dev menu flag — no action needed here
		e) ENV_FILE=${OPTARG};;
		o) DIRECT_OPTION=${OPTARG};;
		v) VERBOSE_FLAG="-v";;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo "${0}:${LINENO} .env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "${0}:${LINENO} SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${BASE_DIR}" ]] && echo "${0}:${LINENO} .env is missing BASE_DIR variable" && exit 1
[[ ! -d "${BASE_DIR}" ]] && echo "${0}:${LINENO} BASE_DIR environment variable is not a directory. Expecting it here ${BASE_DIR}" && exit 1

[[ -z "${VOLUMES_DIR}" ]] && echo "${0}:${LINENO} .env is missing VOLUMES_DIR variable" && exit 1
[[ -z "${ANSIBLE_CEREMONY_DIR}" ]] && echo "${0}:${LINENO} .env is missing ANSIBLE_CEREMONY_DIR variable" && exit 1
[[ -z "${LOG_FILE}" ]] && echo "${0}:${LINENO} .env is missing LOG_FILE variable" && exit 1
[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${AWS_CONDUCTOR_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_CONDUCTOR_SSH_KEY_PATH variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${ANSIBLE_ROLE_INSTALL_PATH}" ]] && echo "${0}:${LINENO} .env is missing ANSIBLE_ROLE_INSTALL_PATH variable" && exit 1

source "${SCRIPTS_DIR}/ansible_helpers.sh"

usage() {
	printf "This is an interface for performing development tasks.\n"
	printf "You may select from the options below\n\n"
}

reset_files() {
	printf "Executing: sudo rm -rf ${CONTRACTS_DIR} ${VOLUMES_DIR} ${ANSIBLE_DIR} ${LOG_FILE} ${AWS_CONDUCTOR_SSH_KEY_PATH} ${AWS_NODES_SSH_KEY_PATH} ${ANSIBLE_ROLE_INSTALL_PATH}\n\n"

	sudo rm -rf \
		${CONTRACTS_DIR} \
		${VOLUMES_DIR} \
		${ANSIBLE_DIR} \
		${LOG_FILE} \
		${AWS_CONDUCTOR_SSH_KEY_PATH} \
		${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_ROLE_INSTALL_PATH}

	# Also clean up Besu role if in Besu mode
	if [[ -n "${BESU_MODE}" ]] && [[ -n "${BESU_ROLE_INSTALL_PATH}" ]]; then
		printf "Executing: sudo rm -rf ${BESU_ROLE_INSTALL_PATH}\n"
		sudo rm -rf ${BESU_ROLE_INSTALL_PATH}
	fi

	printf "ls ${BASE_DIR}\n"
	ls ${BASE_DIR} --color=yes -l
	printf "\n\n"

	# ls ${ANSIBLE_DIR} --color=yes -l

	# ls ${ANSIBLE_ROLE_INSTALL_PATH} --color=yes -l
	printf "\n\n"
}

reset_chain() {
	ANSIBLE_FORCE_COLOR=True \
	ansible-playbook --limit all_quorum \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
 		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_CEREMONY_DIR}/reset.yaml \
}

reset_chain_besu() {
	ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_FORCE_COLOR=True \
	ANSIBLE_ROLES_PATH="${ANSIBLE_ROLE_DIR}/..:${HOME}/.ansible/roles" \
		run_ansible_logged "${LOG_FILE}" \
		-e "ansible_ssh_private_key_file=${AWS_NODES_SSH_KEY_PATH}" \
		-i "${INVENTORY_PATH}" \
		"${ANSIBLE_ROLE_DIR}/test/teardown.yml"
}

run_ansible_playbook() {
	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_CEREMONY_DIR}/goquorum.yaml
}

run_ansible_playbook_besu() {
	ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_FORCE_COLOR=True \
	ANSIBLE_ROLES_PATH="${ANSIBLE_ROLE_DIR}/..:${HOME}/.ansible/roles" \
		run_ansible_logged "${LOG_FILE}" \
		-e "ansible_ssh_private_key_file=${AWS_NODES_SSH_KEY_PATH}" \
		-i "${INVENTORY_PATH}" \
		"${ANSIBLE_ROLE_DIR}/test/validate.yml"
}

print_logo() {
	gradient=$(shuf -i 1-100 -n 1)
	${SCRIPTS_DIR}/printer.sh -f "${gradient}"
	printf "\n\n"
}

test_distribution() {
	local SCRIPT_DIR="${SCRIPTS_DIR}/validation/test_distribution"
	local validator_ip=$(ansible --list-hosts -i "${INVENTORY_PATH}" validator | sed '/:/d ; s/ //g' | head -1)

	cd "${SCRIPT_DIR}"
	npm i &>> ${LOG_FILE}

	RPC_URL="http://${validator_ip}:${RPC_PORT}" \
	CHAIN_ID="${CHAIN_ID}" \
	ISSUER_KEY_PATH="${VOLUMES_DIR}/volume2/distributionIssuer/privatekey" \
	RECIPIENT_KEY_PATH="${VOLUMES_DIR}/volume1/besu-v-1/account/privatekey" \
		node test_distribution.mjs

	cd - > /dev/null
}

items=(
	"Reset network ${CHAIN_NAME} ${NETWORK_TYPE}"
	"Reset files"
	"Run ansible-playbook"
	"Print logo"
	"Test distribution"
	"Exit"
)

[ -n "${DEV_ENABLED}" ] && items+=("Devz")

NC='\033[0m'
RED='\033[0;31m'

if [[ -n "${DIRECT_OPTION}" ]]; then
	if [[ ! "${DIRECT_OPTION}" =~ '^[0-9]+$' ]]; then
		printf "\n\nError: ${RED}${DIRECT_OPTION}${NC} is not a valid option number\n\n"
		exit 1
	fi
	case ${DIRECT_OPTION} in
		1)
			if [[ -n "${BESU_MODE}" ]]; then
				reset_chain_besu
			else
				reset_chain | tee -a "${LOG_FILE}"
			fi;;
		2) reset_files;;
		3)
			if [[ -n "${BESU_MODE}" ]]; then
				run_ansible_playbook_besu
			else
				run_ansible_playbook
			fi;;
		4) print_logo;;
		5) test_distribution;;
		6) printf "Closing\n\n"; exit 0;;
		*) printf "\n\nOoos, ${RED}${DIRECT_OPTION}${NC} is an unknown option\n\n"; exit 1;;
	esac
	exit 0
fi

clear -x

usage

mode_label=""
[[ -n "${BESU_MODE}" ]] && mode_label=" [Besu]"

while true; do
	COLUMNS=1
	PS3=$'\n'"Select option${mode_label}: "
	select item in "${items[@]}"
		case $REPLY in
			1)
				clear -x
				if [[ -n "${BESU_MODE}" ]]; then
					reset_chain_besu
				else
					reset_chain | tee -a "${LOG_FILE}"
				fi
				break;;
			2) clear -x; reset_files; break;;
			3)
				clear -x
				if [[ -n "${BESU_MODE}" ]]; then
					run_ansible_playbook_besu
				else
					run_ansible_playbook
				fi
				break;;
			4) clear -x; print_logo; break;;
			5) clear -x; test_distribution; break;;
			6) printf "Closing\n\n"; exit 0;;
			*)
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done
