#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

APT_NODEJS_VERSION=18.10.0+dfsg-6
APT_NPM_VERSION=9.1.2~ds1-2
APT_GO_VERSION=2:1.19~1
APT_JQ_VERSION=1.6-2.1
APT_PWGEN_VERSION=2.08-2
APT_AWSCLI_VERSION=1.24.8-1
ETHKEY_VERSION=v1.10.26
GETH_VERSION=v1.10.26
ANSIBLE_ROLE_LACE_VERSION=1.0.0.5-test

function print_status() {
	binary=$1
  package=$2
	version=$3

	if which ${binary} &>> ${LOG_FILE}; then
		${SCRIPTS_DIR}/printer.sh -n "${package} Already installed, skipping..."
	else
		${SCRIPTS_DIR}/printer.sh -n "${package} not found, installing"

		if sudo apt install -y ${package}=${version} &>> ${LOG_FILE}; then
			${SCRIPTS_DIR}/printer.sh -s "Installed ${package}"
		else
			${SCRIPTS_DIR}/printer.sh -e "Failed to install ${package}"
		fi
	fi
}

[ -f "${LOG_FILE}" ] || touch ${LOG_FILE}
${SCRIPTS_DIR}/printer.sh -t "Installing dependencies" | tee -a ${LOG_FILE}
${SCRIPTS_DIR}/printer.sh -n "This may take a minute..." | tee -a ${LOG_FILE}

sudo apt-get update &>> ${LOG_FILE}
${SCRIPTS_DIR}/printer.sh -n "Updated system"

print_status "node" "nodejs" ${APT_NODEJS_VERSION}
print_status "npm" "npm" ${APT_NPM_VERSION}
print_status "aws" "awscli" ${APT_AWSCLI_VERSION}
print_status "pwgen" "pwgen" ${APT_PWGEN_VERSION}
print_status "jq" "jq" ${APT_JQ_VERSION}
print_status "go" "golang" ${APT_GO_VERSION}
print_status "ansible" "ansible" ""
print_status "curl" "curl" ""


if which geth &>> ${LOG_FILE}; then
	${SCRIPTS_DIR}/printer.sh -n "geth Already installed, skipping..."
else
	${SCRIPTS_DIR}/printer.sh -n "geth not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION} &>> ${LOG_FILE}
fi

if which ethkey &>> ${LOG_FILE}; then
	${SCRIPTS_DIR}/printer.sh -n "ethkey Already installed, skipping..."
else
	${SCRIPTS_DIR}/printer.sh -n "ethkey not found, installing"
	go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION} &>> ${LOG_FILE}
fi


${SCRIPTS_DIR}/printer.sh -s "Installed dependencies" | tee -a ${LOG_FILE}

