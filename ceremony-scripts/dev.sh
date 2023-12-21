#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts e:h option; do
	case "${option}" in
		e) ENV_FILE=${OPTARG};;
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
[[ -z "${ANSIBLE_DIR}" ]] && echo "${0}:${LINENO} .env is missing ANSIBLE_DIR variable" && exit 1
[[ -z "${LOG_FILE}" ]] && echo "${0}:${LINENO} .env is missing LOG_FILE variable" && exit 1
[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${AWS_CONDUCTOR_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_CONDUCTOR_SSH_KEY_PATH variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${ANSIBLE_ROLE_INSTALL_PATH}" ]] && echo "${0}:${LINENO} .env is missing ANSIBLE_ROLE_INSTALL_PATH variable" && exit 1

usage() {
	printf "This is an interface for performing development tasks.\n"
	printf "You may select from the options below\n\n"
}

printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "Cannot find ${SCRIPTS_DIR}/printer.sh" && exit 1
	${SCRIPTS_DIR}/printer.sh "$@"
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
		${ANSIBLE_DIR}/reset.yaml \
}

run_ansible_playbook() {
	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml
}

print_logo() {
	gradient=$(shuf -i 1-100 -n 1)
	${SCRIPTS_DIR}/printer.sh -f "${gradient}"
	printf "\n\n"
}

get_ansible_vars() {
	[[ -z "${ANSIBLE_DIR}" ]] && echo ".env is missing ANSIBLE_DIR variable" && exit 1
	[[ -z "${BRAND_ANSIBLE_URL}" ]] && echo ".env is missing BRAND_ANSIBLE_URL variable" && exit 1

	printer -t "Fetching ansible variables"

	if [ ! -d "${ANSIBLE_DIR}" ]; then
		source ${ENV_FILE}

		if git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR} &>> ${LOG_FILE}; then
			printer -s "Fetched variables"
		else
			printer -e "Failed to fetch variables"
		fi
	else
		printer -n "Ansible variables present, skipping"
	fi
}

get_inventory() {
	[[ -z "${AWS_CONDUCTOR_SSH_KEY_PATH}" ]] && echo ".env is missing AWS_CONDUCTOR_SSH_KEY_PATH variable" && exit 1
	[[ -z "${SCP_USER}" ]] && echo ".env is missing SCP_USER variable" && exit 1
	[[ -z "${CONDUCTOR_NODE_URL}" ]] && echo ".env is missing CONDUCTOR_NODE_URL variable" && exit 1
	[[ -z "${REMOTE_INVENTORY_PATH}" ]] && echo ".env is missing REMOTE_INVENTORY_PATH variable" && exit 1
	[[ -z "${INVENTORY_PATH}" ]] && echo ".env is missing INVENTORY_PATH variable" && exit 1

	printer -t "Downloading inventory file"

	scp -o StrictHostKeyChecking=no \
		-i ${AWS_CONDUCTOR_SSH_KEY_PATH} \
		"${SCP_USER}"@"${CONDUCTOR_NODE_URL}":"${REMOTE_INVENTORY_PATH}" \
		"${INVENTORY_PATH}"

	if [ -n "${$?}" ] && [ -f "$INVENTORY_PATH" ]; then
		printer -s "$INVENTORY_PATH exists."
	else
		printer -e "Failed to retrieve inventory"
	fi
}

run_ansible() {
	[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable"
	[[ -z "${ANSIBLE_CHAIN_DEPLOY_FORKS}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing ANSIBLE_CHAIN_DEPLOY_FORKS variable"

	printer -t "Executing Ansible Playbook"

	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml

	[ ! $? -eq 0 ] && printer -e "Failed to execute ansible playbook"
}

install_ansible_role() {
	[[ -z "${ANSIBLE_ROLE_INSTALL_PATH}" ]] && echo ".env is missing ANSIBLE_ROLE_INSTALL_PATH variable" && exit 1
	[[ -z "${ANSIBLE_ROLE_VERSION}" ]] && echo ".env is missing ANSIBLE_ROLE_VERSION variable" && exit 1
	[[ -z "${ANSIBLE_ROLE_INSTALL_URL}" ]] && echo ".env is missing ANSIBLE_ROLE_INSTALL_URL variable" && exit 1

	printer -t "Installing Ansible role"

	if [ ! -d "${ANSIBLE_ROLE_INSTALL_PATH}" ]; then
		mkdir -p ${ANSIBLE_ROLE_INSTALL_PATH}

		if git clone \
			--depth 1 \
			--branch ${ANSIBLE_ROLE_VERSION} \
			${ANSIBLE_ROLE_INSTALL_URL} ${ANSIBLE_ROLE_INSTALL_PATH} &>> ${LOG_FILE}
		then
			printer -s "Installed role"
		else
			printer -e "Failed to install ansible role"
		fi
	else
		printer -n "Ansible role present, skipping"
	fi
}

set_decimal() {
	[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable"
	[[ -z "${INVENTORY_PATH}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing INVENTORY_PATH variable"
	[[ -z "${ANSIBLE_DIR}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing ANSIBLE_DIR variable"
	[[ -z "${ANSIBLE_CHAIN_DEPLOY_FORKS}" ]] && printer -e "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing ANSIBLE_CHAIN_DEPLOY_FORKS variable"
	${SCRIPTS_DIR}/get_secrets.sh -e ${ENV_FILE} | tee -a "${LOG_FILE}"
	get_ansible_vars
	get_inventory
	install_ansible_role

	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/copy_nodekeys.yaml

	find "${ANSIBLE_DIR}/keys" -type f -name 'nodekey' -print0 | xargs -0 -I {} sh -c 'mv {} "$(dirname {})/../../../../"'

	reset_chain
	ANSIBLE_HOST_KEY_CHECKING=False \
		ANSIBLE_FORCE_COLOR=True \
		ansible-playbook \
		--extra-vars "lace_genesis_lockup_daily_limit=${GENESIS_LOCKUP_DAILY_LIMIT}" \
		--extra-vars "total_coin_supply=${TOTAL_COIN_SUPPLY}" \
		--extra-vars "lace_genesis_distribution_issuer_balance=${DISTIRBUTION_ISSUER_BALANCE}" \
		--extra-vars "lace_genesis_lockup_last_dist_timestamp=${LOCKUP_TIMESTAMP}" \
		--forks "${ANSIBLE_CHAIN_DEPLOY_FORKS}" \
		--limit all_quorum \
		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/goquorum.yaml
}

items=(
	"Reset network ${CHAIN_NAME} ${NETWORK_TYPE}"
	"Reset files"
	"Run ansible-playbook"
	"Print logo"
	"Set Decimals"
	"Exit"
)

[ -n "${DEV_ENABLED}" ] && items+=("Devz")

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"Select option: "
	select item in "${items[@]}" 
		case $REPLY in
			1) clear -x; reset_chain | tee -a "${LOG_FILE}"; break;;
			2) clear -x; reset_files; break;;
			3) clear -x; run_ansible_playbook; break;;
			4) clear -x; print_logo; break;;
			5) clear -x; set_decimal; break;;
			6) printf "Closing\n\n"; exit 0;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

