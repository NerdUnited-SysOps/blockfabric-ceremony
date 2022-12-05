#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

function print_status() {
  package=$1
	version=$2

	if dpkg -l ${package} &>> ${LOG_FILE}; then
		${SCRIPTS_DIR}/printer.sh -n "${package} Already installed, skipping..."
	else
		if sudo apt install -y ${package}=${version}; then
			${SCRIPTS_DIR}/printer.sh -n "Installed ${package}"
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

print_status "nodejs" ${APT_NODEJS_VERSION}
print_status "npm" ${APT_NPM_VERSION}
print_status "awscli" ${APT_AWSCLI_VERSION}
print_status "pwgen" ${APT_PWGEN_VERSION}
print_status "jq" ${APT_JQ_VERSION}
print_status "golang" ${APT_GO_VERSION}
print_status "ansible" ""
print_status "curl" ""

go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION} &>> ${LOG_FILE}
# print_status "ethkey"

go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION} &>> ${LOG_FILE}
# print_status "geth"

${SCRIPTS_DIR}/printer.sh -s "Installed dependencies" | tee -a ${LOG_FILE}

