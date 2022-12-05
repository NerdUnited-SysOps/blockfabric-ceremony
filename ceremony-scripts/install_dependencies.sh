#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

function print_status() {
  package=$1
  if [ $? -eq 0 ]; then
    ${SCRIPTS_DIR}/printer.sh -n "Installed ${package}"
  else
    ${SCRIPTS_DIR}/printer.sh -e "Failed to install ${package}"
  fi
}

[ -f "${LOG_FILE}" ] || touch ${LOG_FILE}
${SCRIPTS_DIR}/printer.sh -t "Installing dependencies" | tee -a ${LOG_FILE}
${SCRIPTS_DIR}/printer.sh -n "This may take a minute..." | tee -a ${LOG_FILE}

sudo apt-get update &>> ${LOG_FILE}
print_status "Updates"

sudo apt-get install -y nodejs=${APT_NODEJS_VERSION}
print_status "nodejs"

sudo apt-get install -y npm=${APT_NPM_VERSION}
print_status "npm"

sudo apt-get install -y awscli=${APT_AWSCLI_VERSION}
print_status "awscli"

sudo apt-get install -y pwgen=${APT_PWGEN_VERSION} &>> ${LOG_FILE}
print_status "pwgen"

sudo apt-get install -y jq=${APT_JQ_VERSION} &>> ${LOG_FILE}
print_status "jq"

sudo apt-get install -y golang=${APT_GO_VERSION} &>> ${LOG_FILE}
print_status "golang"

go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION} &>> ${LOG_FILE}
print_status "ethkey"

go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION} &>> ${LOG_FILE}
print_status "geth"

python3 -m pip install ansible &>> ${LOG_FILE}
print_status "ansible"

${SCRIPTS_DIR}/printer.sh -s "Installed dependencies" | tee -a ${LOG_FILE}

