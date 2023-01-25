#!/usr/bin/env zsh

set -e

VALIDATION_DIR=$(dirname ${(%):-%N})
SCRIPTS_DIR=$(realpath ${VALIDATION_DIR}/..)
BASE_DIR=$(realpath ${SCRIPTS_DIR}/..)
ENV_FILE=${BASE_DIR}/.env

source ${ENV_FILE}

${VALIDATION_DIR}/validate_chain.sh \
  -d $DATADIR \
  -g $REMOTE_GETH_PATH \
  -i $INVENTORY_PATH \
  -k $AWS_NODES_SSH_KEY_PATH \
  -p $RPC_PORT \
  -r $RPC_PATH \
  -u $NODE_USER \
  -v ${VALIDATION_DIR}/remoteValidate.js

