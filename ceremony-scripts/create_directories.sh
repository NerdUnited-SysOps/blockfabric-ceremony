#!/bin/bash

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

mkdir -p ${KEYS_DIR}/distributionOwner \
    ${KEYS_DIR}/lockupOwner \
    ${CONTRACTS_DIR} \
    ${ANSIBLE_DIR} \
    ${VOLUMES_DIR}/volume1 \
    ${VOLUMES_DIR}/volume2 \
    ${VOLUMES_DIR}/volume3 \
    ${VOLUMES_DIR}/volume4
