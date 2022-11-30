#!/bin/bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

sudo apt-get update # Probably put a specific version on all of these
sudo apt-get install -y awscli=${APT_AWSCLI_VERSION} pwgen=${APT_PWGEN_VERSION} jq=${APT_JQ_VERSION} golang=${APT_GO_VERSION}
go install github.com/ethereum/go-ethereum/cmd/ethkey@${ETHEREUM_VERSION}
go install github.com/ethereum/go-ethereum/cmd/geth@${GETH_VERSION}
python3 -m pip install --user ansible
