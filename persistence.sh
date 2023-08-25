#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts he: option; do
	case "${option}" in
		e) ENV_FILE=${OPTARG};;
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

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${VOLUMES_DIR}" ]] && echo ".env is missing VOLUMES_DIR variable" && exit 1
[[ ! -d "${VOLUMES_DIR}" ]] && echo "VOLUMES_DIR environment variable is not a directory. Expecting it here ${VOLUMES_DIR}" && exit 1

[[ -z "${LOG_FILE}" ]] && echo ".env is missing LOG_FILE variable" && exit 1
[[ ! -f "${LOG_FILE}" ]] && echo "LOG_FILE environment variable is not a file. Expecting it here ${LOG_FILE}" && exit 1

[[ -z "${ETHKEY_PATH}" ]] && echo ".env is missing ETHKEY_PATH variable" && exit 1
[[ ! -f "${ETHKEY_PATH}" ]] && echo "ETHKEY_PATH environment variable is not a file. Expecting it here ${LOG_FILE}" && exit 1

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
	[[ -z "${BRAND_ANSIBLE_URL}" ]] && echo ".env is missing BRAND_ANSIBLE_URL variable" && exit 1
	[[ -z "${ANSIBLE_DIR}" ]] && echo ".env is missing ANSIBLE_DIR variable" && exit 1
	[[ ! -d "${ANSIBLE_DIR}" ]] && echo "ANSIBLE_DIR environment variable is not a directory. Expecting it here ${ANSIBLE_DIR}" && exit 1

	[ -d ${ANSIBLE_DIR} ] || git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR} 
	now=$(date +"%m_%d_%y")
	##	
	cp "${LOG_FILE}" "${ANSIBLE_DIR}/${now}_ceremony.log"
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

	echo "Finished: $(date)" >> "${LOG_FILE}"
	### bootstrap.log will already have a Started: timestamp

	now=$(date +"%m_%d_%y")

	[ -d ${VOLUMES_DIR}/volume1 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume1/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume2 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume2/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume3 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume3/${now}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume4 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume4/${now}_ceremony.log"

	echo "\n\n"
}

persist_distribution_issuer() {
	[[ -z "${AWS_DISTIRBUTION_ISSUER_KEYSTORE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_DISTIRBUTION_ISSUER_KEYSTORE variable" && exit 1
	[[ -z "${AWS_PRIMARY_PROFILE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_PRIMARY_PROFILE variable" && exit 1
	[[ -z "${AWS_DISTIRBUTION_ISSUER_PASSWORD}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_DISTIRBUTION_ISSUER_PASSWORD variable" && exit 1

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
	[[ -z "${AWS_APPROVER_KEYSTORE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_APPROVER_KEYSTORE variable" && exit 1
	[[ -z "${AWS_APPROVER_PASSWORD}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_APPROVER_PASSWORD variable" && exit 1
	[[ -z "${BRAND_AWS_APPROVER_PRIVATE_KEY}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing BRAND_AWS_APPROVER_PRIVATE_KEY variable" && exit 1
	[[ -z "${AWS_PRIMARY_PROFILE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_PRIMARY_PROFILE variable" && exit 1
	[[ -z "${AWS_SECONDARY_PROFILE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_SECONDARY_PROFILE variable" && exit 1
	[[ -z "${AWS_NOTARY_KEYSTORE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_NOTARY_KEYSTORE variable" && exit 1
	[[ -z "${AWS_NOTARY_PASSWORD}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_NOTARY_PASSWORD variable" && exit 1

	# approver -> blockadmin AWS secrets
	upsert_file ${AWS_APPROVER_KEYSTORE} ${VOLUMES_DIR}/volume3/approver/keystore ${AWS_PRIMARY_PROFILE}
	upsert_file ${AWS_APPROVER_PASSWORD} ${VOLUMES_DIR}/volume3/approver/password ${AWS_PRIMARY_PROFILE}

	approver_private_key=$(get_private_key ${VOLUMES_DIR}/volume3/approver)
	upsert_secret ${BRAND_AWS_APPROVER_PRIVATE_KEY} $approver_private_key ${AWS_SECONDARY_PROFILE}

	# notary -> brand AWS secrets
	upsert_file ${AWS_NOTARY_KEYSTORE} ${VOLUMES_DIR}/volume2/notary/keystore ${AWS_SECONDARY_PROFILE}
	upsert_file ${AWS_NOTARY_PASSWORD} ${VOLUMES_DIR}/volume2/notary/password ${AWS_SECONDARY_PROFILE}

	notary_private_key=$(get_private_key ${VOLUMES_DIR}/volume2/notary)
	upsert_secret ${BLOCK_FABRIC_AWS_NOTARY_PRIVATE_KEY} $notary_private_key ${AWS_PRIMARY_PROFILE}

	# contract addresses
	temp_dir=${BASE_DIR}/tmp
	persist_address_file ${BRAND_AWS_BRIDGE_CONTRACT_ADDRESS} ${temp_dir}/bridge_address ${AWS_SECONDARY_PROFILE}
	persist_address_file ${BRIDGE_MINTER_CONTRACT_ADDRESS} ${temp_dir}/bridge_minter_address ${AWS_PRIMARY_PROFILE}
	persist_address_file ${TOKEN_CONTRACT_ADDRESS} ${temp_dir}/token_contract_address ${AWS_PRIMARY_PROFILE}

	# secondary contracts
	persist_address_file ${BLOCK_FABRIC_AWS_BRIDGE_CONTRACT_ADDRESS} ${temp_dir}/bridge_address ${AWS_PRIMARY_PROFILE}
}

inspect() {
	inspect_path=$1

	${ETHKEY_PATH} inspect \
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
	PS3=$'\n'"${CHAIN_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}" 
		case $REPLY in
			1) persist_distribution_issuer | tee -a ${LOG_FILE}; break;;
			2) save_log_file | tee -a ${LOG_FILE}; break;;
			3) save_ansible_vars | tee -a ${LOG_FILE}; break;;
			4) printf "Closing\n\n"; exit 0;;
			*) 
				printf "\n\nOoops, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

