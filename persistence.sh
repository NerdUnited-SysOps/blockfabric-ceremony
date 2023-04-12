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
	printer -n "Persisting value to ${upsert_key}"

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
	[ -d ${ANSIBLE_DIR} ] || git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR} 
	now=$(date +"%m_%d_%y")
	# Prepend bootstrap.log into ceremony.log before github commits and before it's copied to volumes/
	if [ -f "${HOME}/bootstrap.log" ]; then
		COMBINED=$(cat ~/bootstrap.log; cat ${LOG_FILE})
		echo "$COMBINED" > ${LOG_FILE}
	fi

	echo "Finished: $(date)" >> "${LOG_FILE}"
	## bootstrap.log will already have a Started: timestamp
	cp ${LOG_FILE} "${ANSIBLE_DIR}/ceremony_${now}.log"
	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -B "ceremony-artifacts-${now}"
	git -C ${ANSIBLE_DIR}/ add ${ANSIBLE_DIR}/ &>> ${LOG_FILE}
	git -C ${ANSIBLE_DIR}/ commit -m "Committing produced artifacts"
	git -C ${ANSIBLE_DIR}/ push origin HEAD --force --porcelain &>> ${LOG_FILE}

	printer -s "Persisted artifacts"
}

save_log_file() {
	printer -t "Copying ${LOG_FILE} file to all volumes"
	echo "\n"

	now=$(date +"%m_%d_%y")

	[ -d ${VOLUMES_DIR}/volume1 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume1/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume2 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume2/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume3 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume3/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume4 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume4/${now}_ceremony.log"

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
	upsert_file ${AWS_APPROVER_KEYSTORE} ${VOLUMES_DIR}/volume3/approver/keystore ${AWS_PRIMARY_PROFILE}
	upsert_file ${AWS_APPROVER_PASSWORD} ${VOLUMES_DIR}/volume3/approver/password ${AWS_PRIMARY_PROFILE}

	approver_private_key=$(get_private_key ${VOLUMES_DIR}/volume3/approver)
	upsert_secret ${AWS_APPROVER_PRIVATE_KEY} $approver_private_key ${AWS_SECONDARY_PROFILE}

	# notary -> brand AWS secrets
	notary_private_key=$(get_private_key ${VOLUMES_DIR}/volume3/approver)
	upsert_secret ${AWS_APPROVER_PRIVATE_KEY} $notary_private_key ${AWS_SECONDARY_PROFILE}
	upsert_file ${AWS_NOTARY_KEYSTORE} ${VOLUMES_DIR}/volume2/notary/keystore ${AWS_SECONDARY_PROFILE}
	upsert_file ${AWS_NOTARY_PASSWORD} ${VOLUMES_DIR}/volume2/notary/password ${AWS_SECONDARY_PROFILE}

	notary_private_key=$(get_private_key ${VOLUMES_DIR}/volume2/notary)
	upsert_secret ${AWS_NOTARY_PRIVATE_KEY} $notary_private_key ${AWS_PRIMARY_PROFILE}

	# contract addresses
	temp_dir=${BASE_DIR}/tmp
	persist_address_file ${BRIDGE_CONTRACT_ADDRESS} ${temp_dir}/bridge_address ${AWS_PRIMARY_PROFILE}
	persist_address_file ${BRIDGE_MINTER_CONTRACT_ADDRESS} ${temp_dir}/bridge_minter_address ${AWS_PRIMARY_PROFILE}
	persist_address_file ${TOKEN_CONTRACT_ADDRESS} ${temp_dir}/token_contract_address ${AWS_PRIMARY_PROFILE}

	# secondary contracts
	persist_address_file ${BRIDGE_CONTRACT_ADDRESS} ${temp_dir}/bridge_address ${AWS_SECONDARY_PROFILE}
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
	"Persist distribution issuer wallet (chain creation)"
	"Persist bridge keys"
	"Save Log File to volumes"
	"Persist operational variables (cli args, variables, addresses, etc)"
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
			1) persist_distribution_issuer | tee -a ${LOG_FILE}; break;;
			2) persist_bridge_keys | tee -a ${LOG_FILE}; break;;
			3) save_log_file | tee -a ${LOG_FILE}; break;;
			4) save_ansible_vars | tee -a ${LOG_FILE}; break;;
			5) printf "Closing\n\n"; exit 0;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

