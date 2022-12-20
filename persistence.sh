#!/usr/bin/zsh

set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)

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
	printf "This is an interface for moving assets generated in the ceremony.\n"
	printf "You may select from the options below\n\n"
}

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

persist_distribution_issuer() {
	printer -t "Saving artifacts"

	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -b ceremony-artifacts
	git -C ${ANSIBLE_DIR}/ add ${ANSIBLE_DIR}/ &>> ${LOG_FILE}
	git -C ${ANSIBLE_DIR}/ commit -m "Committing produced artifacts"
	git -C ${ANSIBLE_DIR}/ push origin HEAD --force --porcelain &>> ${LOG_FILE}

	printer -s "Persisted artifacts"
}

save_ansible_vars() {
	# Get the private key (or the keystore & password)
	secret=$(aws secretsmanager \
		put-secret-value \
		--secret-id ${AWS_DISTIRBUTION_ISSUER_KEY_NAME} \
		--secret-string ${PRIVATE_KEY} &)
			wait

			if [ -n "${secret}" ]; then
				printer -s "Generated distribution wallet"
			else
				aws secretsmanager \
					create-secret \
					--name ${AWS_DISTIRBUTION_ISSUER_KEY_NAME} \
					--secret-string ${PRIVATE_KEY}

				if [ $? -eq 0 ]; then
					printer -s "Generated distribution issuer wallet"
				else
					printer -e "Failed to push distribution wallet to secret manager"
				fi
			fi
}

COLUMNS=1

items=(
	"Persist distribution issuer wallet"
	"Persist chain variables (cli args, genesis, addresses, etc)"
	"Exit"
)

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	PS3=$'\n'"Select option: "
	select item in "${items[@]}" 
		case $REPLY in
			1) clear -x; persist_distribution_issuer; break;;
			2) clear -x; save_ansible_vars; break;;
			5) printf "Closing\n\n"; exit 1;;
			6) clear -x; dev; break;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

