#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Environment config file"
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
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}" >&2
	exit 1
else
	source "${ENV_FILE}"
fi

[[ -z "${ANSIBLE_DIR}" ]] && echo "${0}:${LINENO} .env is missing ANSIBLE_DIR variable" && exit 1
[[ -z "${BRAND_ARTIFACT_REPO_URL}" ]] && echo "${0}:${LINENO} .env is missing BRAND_ARTIFACT_REPO_URL variable" && exit 1
[[ -z "${CEREMONY_TYPE}" ]] && echo "${0}:${LINENO} .env is missing CEREMONY_TYPE variable" && exit 1
[[ -z "${LOG_FILE}" ]] && echo "${0}:${LINENO} .env is missing LOG_FILE variable" && exit 1
[[ -z "${NETWORK_TYPE}" ]] && echo "${0}:${LINENO} .env is missing NETWORK_TYPE variable" && exit 1
[[ -z "${VOLUMES_DIR}" ]] && echo "${0}:${LINENO} .env is missing VOLUMES_DIR variable" && exit 1
[[ -z "${SHARED_DIR}" ]] && echo "${0}:${LINENO} .env is missing SHARED_DIR variable" && exit 1
[[ -z "${SCRIPTS_DIR}" ]] && echo "${0}:${LINENO} .env is missing SCRIPTS_DIR variable" && exit 1

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

echo "Finished: $(date)" >> "${LOG_FILE}"
	### Prepend bootstrap.log into ceremony.log before github commits and before it's copied to volumes/
	if [ -f "${SHARED_DIR}/bootstrap.log" ]; then
		COMBINED=$(cat ${SHARED_DIR}/bootstrap.log; cat ${LOG_FILE})
		echo "${COMBINED}" > "${LOG_FILE}"
	fi

	now=$(date +"%m_%d_%y")

	log_name="${now}_${CEREMONY_TYPE}_ceremony.log"
	[ -d ${VOLUMES_DIR}/volume1 ] && cp -v ${LOG_FILE} "${VOLUMES_DIR}/volume1/${log_name}"
	[ -d ${VOLUMES_DIR}/volume2 ] && cp -v ${LOG_FILE} "${VOLUMES_DIR}/volume2/${log_name}"
	[ -d ${VOLUMES_DIR}/volume3 ] && cp -v ${LOG_FILE} "${VOLUMES_DIR}/volume3/${log_name}"
	[ -d ${VOLUMES_DIR}/volume4 ] && cp -v ${LOG_FILE} "${VOLUMES_DIR}/volume4/${log_name}"

	repo="${SHARED_DIR}/ansible"
	[ -d ${repo} ] || git clone ${BRAND_ARTIFACT_REPO_URL} ${repo} | tee -a ${LOG_FILE}

	if [ -d "${repo}" ]; then
		mkdir -p "${repo}/${NETWORK_TYPE}/${CEREMONY_TYPE}"
		cp "${LOG_FILE}" "${repo}/${NETWORK_TYPE}/${CEREMONY_TYPE}/${log_name}" | tee -a ${LOG_FILE}
		git -C ${repo}/ checkout -B "${NETWORK_TYPE}-${CEREMONY_TYPE}-${now}" | tee -a ${LOG_FILE}
		git -C ${repo}/ add . &>> ${LOG_FILE} | tee -a ${LOG_FILE}

		GIT_COMMITTER_EMAIL="ceremony@email.com" git \
			-C ${repo}/ \
			commit -m "Committing produced artifacts for ${CEREMONY_TYPE}" \
			--author="ceremony-script <ceremony@email.com>" | tee -a ${LOG_FILE}

		git -C ${repo}/ push origin HEAD --force --porcelain &>> ${LOG_FILE} | tee -a ${LOG_FILE}

		printer -s "Persisted artifacts" | tee -a ${LOG_FILE}
	else
		printer -e "Failed to persist artifacts" | tee -a "${LOG_FILE}"
	fi
