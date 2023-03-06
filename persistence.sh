#!/usr/bin/env zsh

set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)
ETHKEY=${HOME}/go/bin/ethkey

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

upsert_secret() {
	upsert_key=$1
	upsert_value=$2
	profile=$3
	printer -n "Persisting ${upsert_val} to ${upsert_key}"

	secret=$(aws secretsmanager \
		put-secret-value \
		--secret-id ${upsert_key} \
		--profile ${profile} \
		--secret-string ${upsert_value} &)

			if [ -n "${secret}" ]; then
				printer -s "Complete"
			else
				aws secretsmanager \
					create-secret \
					--name ${upsert_key} \
					--profile ${profile} \
					--secret-string ${upsert_value}

				if [ $? -eq 0 ]; then
					printer -s "Complete"
				else
					printer -e "Failed to pserist ${upsert_key}"
				fi
				fi
}

upsert_file() {
	upsert_key=$1
	upsert_file=$2
	profile=$3
	printer -n "Persisting ${upsert_file} to ${upsert_key}"
	upsert_value=$(cat ${upsert_file})

	secret=$(aws secretsmanager \
		put-secret-value \
		--secret-id ${upsert_key} \
		--profile ${profile} \
		--secret-string ${upsert_value} &)

			if [ -n "${secret}" ]; then
				printer -s "Complete"
			else
				aws secretsmanager \
					create-secret \
					--name ${upsert_key} \
					--profile ${profile} \
					--secret-string ${upsert_value}

				if [ $? -eq 0 ]; then
					printer -s "Complete"
				else
					printer -e "Failed to pserist ${upsert_key}"
				fi
				fi
}

save_ansible_vars() {
	# Prepend bootstrap.log into ceremony.log before github commits and copies to volumes
	x=$(cat ~/bootstrap.log; cat ${LOG_FILE})
	echo "$x" > ${LOG_FILE}.combined
	mv ${LOG_FILE} ${LOG_FILE}.orig
	mv ${LOG_FILE}.combined ${LOG_FILE}
	
	cp ${LOG_FILE} ${ANSIBLE_DIR}/ceremony.log
	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -B ceremony-artifacts
	git -C ${ANSIBLE_DIR}/ add ${ANSIBLE_DIR}/ &>> ${LOG_FILE}
	git -C ${ANSIBLE_DIR}/ commit -m "Committing produced artifacts"
	git -C ${ANSIBLE_DIR}/ push origin HEAD --force --porcelain &>> ${LOG_FILE}

	printer -s "Persisted artifacts"
}

save_log_file() {
	printer -t "Copying ${LOG_FILE} file to all volumes"
	echo "\n"

	cp -v $LOG_FILE ${VOLUMES_DIR}/volume1/
	cp -v $LOG_FILE ${VOLUMES_DIR}/volume2/
	cp -v $LOG_FILE ${VOLUMES_DIR}/volume3/
	cp -v $LOG_FILE ${VOLUMES_DIR}/volume4/

	echo "\n\n"
}

persist_distribution_issuer() {
	# Get the private key (or the keystore & password)
	upsert_file ${AWS_DISTIRBUTION_ISSUER_KEYSTORE} ${VOLUMES_DIR}/volume1/distributionIssuer/keystore ${AWS_PRIMARY_PROFILE}
	upsert_file ${AWS_DISTIRBUTION_ISSUER_PASSWORD} ${VOLUMES_DIR}/volume1/distributionIssuer/password ${AWS_PRIMARY_PROFILE}
}

persist_address_file() {
	key_name=$1
	file_path=$2
	profile=$3
	printer -n "Persisting ${file_path} to ${key_name}"

	if [ -f "${file_path}" ]; then
		upsert_file ${key_name} ${file_path} ${profile}
	else
		printer -e "Missing ${file_path}"
	fi
}

persist_bridge_keys() {	
	# approver -> blockadmin AWS secrets
	upsert_file ${AWS_APPROVER_KEYSTORE} ${VOLUMES_DIR}/volume5/approver/keystore ${AWS_PRIMARY_PROFILE}
	upsert_file ${AWS_APPROVER_PASSWORD} ${VOLUMES_DIR}/volume5/approver/password ${AWS_PRIMARY_PROFILE}

	approver_private_key=$(get_private_key ${VOLUMES_DIR}/volume5/approver)
	upsert_secret ${AWS_APPROVER_PRIVATE_KEY} $approver_private_key ${AWS_SECONDARY_PROFILE}

	# notary -> brand AWS secrets
	upsert_file ${AWS_NOTARY_KEYSTORE} ${VOLUMES_DIR}/volume5/notary/keystore ${AWS_SECONDARY_PROFILE}
	upsert_file ${AWS_NOTARY_PASSWORD} ${VOLUMES_DIR}/volume5/notary/password ${AWS_SECONDARY_PROFILE}

	notary_private_key=$(get_private_key ${VOLUMES_DIR}/volume5/notary)
	upsert_secret ${AWS_NOTARY_PRIVATE_KEY} $notary_private_key ${AWS_PRIMARY_PROFILE}

	# contract addresses
	volume5=${VOLUMES_DIR}/volume5
	persist_address_file ${BRIDGE_CONTRACT_ADDRESS} ${volume5}/bridge_address ${AWS_PRIMARY_PROFILE}
	persist_address_file ${BRIDGE_MINTER_CONTRACT_ADDRESS} ${volume5}/bridge_minter_address ${AWS_PRIMARY_PROFILE}
	persist_address_file ${TOKEN_CONTRACT_ADDRESS} ${volume5}/token_address ${AWS_PRIMARY_PROFILE}

	# secondary contracts
	persist_address_file ${BRIDGE_CONTRACT_ADDRESS} ${volume5}/bridge_address ${AWS_SECONDARY_PROFILE}
}

inspect() {
	inspect_path=$1

	${ETHKEY} inspect \
		--private \
		--passwordfile ${inspect_path}/password \
		${inspect_path}/keystore
}

get_private_key() {
	inspect_path=$1
	inspected_content=$(inspect "${inspect_path}")
	echo "${inspected_content}" | sed -n "s/Private\skey:\s*\(.*\)/\1/p" | tr -d '\n'
}

items=(
	"Persist distribution issuer wallet"
	"Persist chain variables (cli args, genesis, addresses, etc)"
	"Save Log File to volumes"
	"Persist bridge keys"
	"Exit"
)

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"${BRAND_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}" 
		case $REPLY in
			1) persist_distribution_issuer; break;;
			2) save_ansible_vars; break;;
			3) save_log_file; break;;
			4) persist_bridge_keys; break;;
			5) printf "Closing\n\n"; exit 0;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

