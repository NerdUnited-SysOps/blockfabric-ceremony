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
	[[ -z "${ANSIBLE_CEREMONY_DIR}" ]] && echo ".env is missing ANSIBLE_CEREMONY_DIR variable" && exit 1
	[[ ! -d "${ANSIBLE_CEREMONY_DIR}" ]] && echo "ANSIBLE_CEREMONY_DIR environment variable is not a directory. Expecting it here ${ANSIBLE_CEREMONY_DIR}" && exit 1
	printer -t "Persisting Values"

	[ -d ${ANSIBLE_DIR} ] || git clone ${BRAND_ANSIBLE_URL} ${ANSIBLE_DIR} 
	now=$(date +"%m_%d_%y")
	##	
	cp "${LOG_FILE}" "${ANSIBLE_CEREMONY_DIR}/${now}_${CEREMONY_TYPE}_ceremony.log"
	git config --global user.name "ceremony-script"
	git config --global user.email "ceremony@email.com"
	git -C ${ANSIBLE_DIR}/ checkout -B "${CEREMONY_TYPE}-${now}"
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

	[ -d ${VOLUMES_DIR}/volume1 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume1/${now}_${CEREMONY_TYPE}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume2 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume2/${now}_${CEREMONY_TYPE}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume3 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume3/${now}_${CEREMONY_TYPE}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume4 ] && cp -v $LOG_FILE "${VOLUMES_DIR}/volume4/${now}_${CEREMONY_TYPE}_ceremony.log"
	printer -s "Complete"
}

persist_distribution_issuer() {
	[[ -z "${AWS_DISTIRBUTION_ISSUER_KEYSTORE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_DISTIRBUTION_ISSUER_KEYSTORE variable" && exit 1
	[[ -z "${AWS_PRIMARY_PROFILE}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_PRIMARY_PROFILE variable" && exit 1
	[[ -z "${AWS_DISTIRBUTION_ISSUER_PASSWORD}" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} .env is missing AWS_DISTIRBUTION_ISSUER_PASSWORD variable" && exit 1
	printer -t "Saving Values"

	# Get the private key (or the keystore & password)
	upsert_file ${AWS_DISTIRBUTION_ISSUER_KEYSTORE} ${VOLUMES_DIR}/volume2/distributionIssuer/keystore ${AWS_PRIMARY_PROFILE}
	upsert_file ${AWS_DISTIRBUTION_ISSUER_PASSWORD} ${VOLUMES_DIR}/volume2/distributionIssuer/password ${AWS_PRIMARY_PROFILE}

	distribution_issuer_pk=$(get_private_key ${VOLUMES_DIR}/volume2/distributionIssuer)
	upsert_secret "L2_FUNDING_PK" $distribution_issuer_pk ${AWS_PRIMARY_PROFILE}
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

clear -x


persist_distribution_issuer

save_log_file

save_ansible_vars

