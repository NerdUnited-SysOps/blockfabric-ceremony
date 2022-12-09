#!/bin/bash

source ../../.common.sh
cd $(dirname "${BASH_SOURCE[0]}")

./validate_chain.sh \
  -d $DATADIR \
  -g $GETH_PATH \
  -i $INVENTORY_PATH \
  -k $AWS_NODES_SSH_KEY_PATH \
  -p $RPC_PORT \
  -r $RPC_PATH \
  -u $NODE_USER

