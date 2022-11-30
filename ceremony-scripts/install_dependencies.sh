#!/bin/bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

echo "Installing dependencies"

sudo apt-get update

sudo apt-get install -y \
    nodejs=${APT_NODEJS_VERSION} \
    npm=${APT_NPM_VERSION} \
    awscli=${APT_AWSCLI_VERSION} \
    pwgen=${APT_PWGEN_VERSION} \
    jq=${APT_JQ_VERSION} \
    golang=${APT_GO_VERSION} > /dev/null

go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHKEY_VERSION}
go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION}
python3 -m pip install --user ansible
