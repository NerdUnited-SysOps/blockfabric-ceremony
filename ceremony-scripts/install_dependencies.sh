#!/usr/bin/zsh

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
ENV_FILE="${BASE_DIR}/.env"
ETHKEY=${HOME}/go/bin/ethkey
GETH=${HOME}/go/bin/geth

usage() {
	echo "Options"
	echo "  -e : Path to the ethkey binary"
	echo "  -f : Path to env file"
	echo "  -g : Path to the geth binary"
	echo "  -h : This help message"
	echo "  -s : Script directory to reference other scripts"
}

while getopts e:f:g:hs: option; do
	case "${option}" in
		e)
			ETHKEY=${OPTARG}
			;;
		g)
			GETH=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		l)
			LOG_FILE=${OPTARG}
			;;
		s)
			SCRIPTS_DIR=${OPTARG}
			;;
	esac
done

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

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


if which ${GETH} &>> ${LOG_FILE}; then
	printer -n "geth Already installed, skipping..."
else
	printer -n "geth not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION} &>> ${LOG_FILE}
fi

if which ${ETHKEY} &>> ${LOG_FILE}; then
	printer -n "ethkey Already installed, skipping..."
else
	printer -n "ethkey not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION} &>> ${LOG_FILE}
fi

printer -s "Dependencies installed" | tee -a ${LOG_FILE}

