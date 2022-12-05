ansible-playbook --limit all_quorum -i ${INVENTORY_PATH} ${ANSIBLE_DIR}/goquorum.yaml --private-key=${AWS_NODES_SSH_KEY_PATH}
