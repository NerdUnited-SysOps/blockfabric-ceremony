#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Path to the env file"
}

while getopts e:f:g:hs: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
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

printer() {
	[[ ! -f "${SCRIPTS_DIR}/printer.sh" ]] && echo "${ZSH_ARGZERO}:${0}:${LINENO} ${SCRIPTS_DIR}/printer.sh file doesn't exist" && exit 1
	${SCRIPTS_DIR}/printer.sh "$@"
}

[[ -z "${LOG_FILE}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing LOG_FILE" && exit 1
[[ -z "${SCRIPTS_DIR}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing SCRIPTS_DIR" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "${ZSH_ARGZERO}:${LINENO} SCRIPTS_DIR isn't a directory. ${SCRIPTS_DIR}" && exit 1
[[ -z "${GETH_PATH}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing GETH_PATH" && exit 1
[[ -z "${ETHKEY_PATH}" ]] && echo "${ZSH_ARGZERO}:${LINENO} .env is missing ETHKEY_PATH" && exit 1

# Expected versions
APT_GO_VERSION=2:1.19~1
APT_JQ_VERSION=1.6-2.1
APT_PWGEN_VERSION=2.08-2
APT_AWSCLI_VERSION=1.24.8-1
APT_ANSIBLE_VERSION=7.0.0+dfsg-1
APT_CURL_VERSION=7.84.0-2
ETHKEY_VERSION=v1.10.26
GETH_VERSION=v1.10.26

verify_binary() {
	binary=$1
	package=$2
	version=$3

	if which ${binary} &>> ${LOG_FILE}; then
		installed=$(dpkg -s ${package} 2>/dev/null | grep '^Version:' | awk '{print $2}')
		if [[ "${installed}" == "${version}" ]]; then
			printer -n "${package} ${version} verified" | tee -a ${LOG_FILE}
		else
			printer -n "${package} found (version: ${installed:-unknown}, expected: ${version})" | tee -a ${LOG_FILE}
		fi
	else
		printer -e "${package} not found — expected ${version}" | tee -a ${LOG_FILE}
	fi
}

[ -f "${LOG_FILE}" ] || touch ${LOG_FILE}
printer -t "Verifying dependencies" | tee -a ${LOG_FILE}

verify_binary "aws" "awscli" ${APT_AWSCLI_VERSION}
verify_binary "pwgen" "pwgen" ${APT_PWGEN_VERSION}
verify_binary "jq" "jq" ${APT_JQ_VERSION}
verify_binary "go" "golang" ${APT_GO_VERSION}
verify_binary "ansible" "ansible" "${APT_ANSIBLE_VERSION}"
verify_binary "curl" "curl" "${APT_CURL_VERSION}"

if which ${GETH_PATH} &>> ${LOG_FILE}; then
	printer -n "geth verified" | tee -a ${LOG_FILE}
else
	printer -e "geth not found" | tee -a ${LOG_FILE}
fi

if which ${ETHKEY_PATH} &>> ${LOG_FILE}; then
	printer -n "ethkey verified" | tee -a ${LOG_FILE}
else
	printer -e "ethkey not found" | tee -a ${LOG_FILE}
fi

printer -s "Dependencies verified" | tee -a ${LOG_FILE}
