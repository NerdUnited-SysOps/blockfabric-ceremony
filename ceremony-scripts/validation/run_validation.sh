#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../../.common.sh

./validation_chain.sh \
  -d $DATADIR \
  -g $GETH_PATH \
  -i $INVENTORY_PATH \ #fill this in
  -k $AWS_NODES_SSH_KEY_PATH \  
  -p $RPC_PORT \
  -r $RPC_PATH \
  -u $NODE_USER

