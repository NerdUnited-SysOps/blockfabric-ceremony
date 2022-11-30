#!/bin/bash

export BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

rm -r ${KEYS_DIR} \
    ${CONTRACTS_DIR} \
    ${VOLUMES_DIR}
