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

upsert_file() {
	upsert_key=$1
	upsert_file=$2
	printer -n "Persisting ${upsert_file} to ${upsert_key}"
	upsert_value=$(cat ${upsert_file})

	secret=$(aws secretsmanager \
		put-secret-value \
		--secret-id ${upsert_key} \
		--secret-string ${upsert_value} &)

			if [ -n "${secret}" ]; then
				printer -s "Complete"
			else
				aws secretsmanager \
					create-secret \
					--name ${upsert_key} \
					--secret-string ${upsert_value}

				if [ $? -eq 0 ]; then
					printer -s "Complete"
				else
					printer -e "Failed to pserist ${upsert_key}"
				fi
				fi
}

save_ansible_vars() {
	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -B ceremony-artifacts
	git -C ${ANSIBLE_DIR}/ add ${ANSIBLE_DIR}/ &>> ${LOG_FILE}
	git -C ${ANSIBLE_DIR}/ commit -m "Committing produced artifacts"
	git -C ${ANSIBLE_DIR}/ push origin HEAD --force --porcelain &>> ${LOG_FILE}

	printer -s "Persisted artifacts"
}

persist_distribution_issuer() {
	# Get the private key (or the keystore & password)
	upsert_file ${AWS_DISTIRBUTION_ISSUER_KEYSTORE} ${VOLUMES_DIR}/volume1/distributionIssuer/keystore
	upsert_file ${AWS_DISTIRBUTION_ISSUER_PASSWORD} ${VOLUMES_DIR}/volume1/distributionIssuer/password
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
			1) persist_distribution_issuer; break;;
			2) save_ansible_vars; break;;
			5) printf "Closing\n\n"; exit 1;;
			6) clear -x; dev; break;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

