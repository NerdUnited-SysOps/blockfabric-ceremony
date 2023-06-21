#!/usr/bin/env zsh

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
ENV_FILE=${BASE_DIR}/.env

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
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

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

	printf "ls ${BASE_DIR}\n"
	ls ${BASE_DIR} --color=yes -l
	printf "\n\n"

	# ls ${ANSIBLE_DIR} --color=yes -l

	# ls ${ANSIBLE_ROLE_INSTALL_PATH} --color=yes -l
	printf "\n\n"
}

reset_chain() {
	ansible-playbook --limit all_quorum \
 		-i ${INVENTORY_PATH} \
		--private-key=${AWS_NODES_SSH_KEY_PATH} \
		${ANSIBLE_DIR}/reset.yaml \
		--forks 10 
}

run_ansible_playbook() {
	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
		--forks 20 \
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

items=(
	"Reset chain"
	"Reset files"
	"Run ansible-playbook"
	"Print logo"
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
			1) clear -x; reset_chain; break;;
			2) clear -x; reset_files; break;;
			3) clear -x; run_ansible_playbook; break;;
			4) clear -x; print_logo; break;;
			5) printf "Closing\n\n"; exit 0;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

