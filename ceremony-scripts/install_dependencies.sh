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
	echo "Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

check_env() {
	var_name=$1
	var_val=$2
	[[ -z "${var_val}" ]] && echo ".env is missing ${var_name} variable" && exit 1
}

check_file_path() {
	file_path=$1
	[[ ! -f "${file_path}" ]] && echo "Cannot find ${file_path}" && exit 1
}

printer() {
	check_file_path "${SCRIPTS_DIR}/printer.sh"
	${SCRIPTS_DIR}/printer.sh "$@"
}

check_env "LOG_FILE" "${LOG_FILE}"
check_env "GETH_PATH" "${GETH_PATH}"
check_env "ETHKEY_PATH" "${ETHKEY_PATH}"

APT_NODEJS_VERSION=18.10.0+dfsg-6
APT_NPM_VERSION=9.1.2~ds1-2
APT_GO_VERSION=2:1.19~1
APT_JQ_VERSION=1.6-2.1
APT_PWGEN_VERSION=2.08-2
APT_AWSCLI_VERSION=1.24.8-1
APT_ANSIBLE_VERSION=7.0.0+dfsg-1
APT_CURL_VERSION=7.84.0-2
ETHKEY_VERSION=v1.10.26
GETH_VERSION=v1.10.26
ANSIBLE_ROLE_LACE_VERSION=1.0.0.5-test

print_status() {
	binary=$1
  package=$2
	version=$3

	if which ${binary} &>> ${LOG_FILE}; then
		printer -n "${package} Already installed, skipping..."
	else
		printer -n "${package} not found, installing"

		if sudo apt install -y ${package}=${version} &>> ${LOG_FILE}; then
			printer -s "Installed ${package}"
		else
			printer -e "Failed to install ${package}"
		fi
	fi
}

[ -f "${LOG_FILE}" ] || touch ${LOG_FILE}
printer -t "Installing dependencies" | tee -a ${LOG_FILE}
printer -n "This may take a minute..." | tee -a ${LOG_FILE}

sudo apt-get update &>> ${LOG_FILE}
printer -n "Updated system"

print_status "node" "nodejs" ${APT_NODEJS_VERSION}
print_status "npm" "npm" ${APT_NPM_VERSION}
print_status "aws" "awscli" ${APT_AWSCLI_VERSION}
print_status "pwgen" "pwgen" ${APT_PWGEN_VERSION}
print_status "jq" "jq" ${APT_JQ_VERSION}
print_status "go" "golang" ${APT_GO_VERSION}
print_status "ansible" "ansible" "${APT_ANSIBLE_VERSION}"
print_status "curl" "curl" "${APT_CURL_VERSION}"


if which ${GETH_PATH} &>> ${LOG_FILE}; then
	printer -n "geth Already installed, skipping..."
else
	printer -n "geth not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION} &>> ${LOG_FILE}
fi

if which ${ETHKEY_PATH} &>> ${LOG_FILE}; then
	printer -n "ethkey Already installed, skipping..."
else
	printer -n "ethkey not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION} &>> ${LOG_FILE}
fi

printer -s "Dependencies installed" | tee -a ${LOG_FILE}

