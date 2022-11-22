#!/bin/bash

# This script REQUIRES various environment variables to be set.
# For some of them, try to calculate them from other environment variables.

if [ -z "${RPC_IPS}" ]; then
  if [ -n "${RPC_IPS_FILE}" ]; then
    RPC_IPS=$(cat ${AWS_RPC_IPS_FILE} | tr "\n" " ")
  elif [ -n "${AWS_RPC_IPS}" ] && [ -n "${AZURE_RPC_IPS}" ] && [ -n "${GCP_RPC_IPS}" ]; then
    RPC_IPS="${AWS_RPC_IPS} ${AZURE_RPC_IPS} ${GCP_RPC_IPS}"
  elif [ -n "${AWS_RPC_IPS_FILE}" ] && [ -n "${AZURE_RPC_IPS_FILE}" ] && [ -n "${GCP_RPC_IPS_FILE}" ]; then
    RPC_IPS=$(cat ${AWS_RPC_IPS_FILE} ${AZURE_RPC_IPS_FILE} ${GCP_RPC_IPS_FILE} | tr "\n" " ")
  else
    echo "ERROR: Reguired envrionment variable(s) missing"
    exit 1
  fi  
fi

if [ -z "${VALIDATOR_IPS}" ]; then
  if [ -n "${VALIDATOR_IPS_FILE}" ]; then
    VALIDATOR_IPS=$(cat ${AWS_VALIDATOR_IPS_FILE} | tr "\n" " ")
  elif [ -n "${AWS_VALIDATOR_IPS}" ] && [ -n "${AZURE_VALIDATOR_IPS}" ] && [ -n "${GCP_VALIDATOR_IPS}" ]; then
    VALIDATOR_IPS="${AWS_VALIDATOR_IPS} ${AZURE_VALIDATOR_IPS} ${GCP_VALIDATOR_IPS}"
  elif [ -n "${AWS_VALIDATOR_IPS_FILE}" ] && [ -n "${AZURE_VALIDATOR_IPS_FILE}" ] && [ -n "${GCP_VALIDATOR_IPS_FILE}" ]; then
    VALIDATOR_IPS=$(cat ${AWS_VALIDATOR_IPS_FILE} ${AZURE_VALIDATOR_IPS_FILE} ${GCP_VALIDATOR_IPS_FILE} | tr "\n" " ")
  else
    echo "ERROR: Reguired envrionment variable(s) missing"
    exit 1
  fi  
fi

[ -z "${PUBLIC_IPS}" ] && PUBLIC_IPS="${RPC_IPS} ${VALIDATOR_IPS}"

if [ -z "${NETWORK_ENVIRONMENT}" ] || [ -z "${NETWORK_ID}" ] || [ -z "${NETWORK_NAME}" ] || [ -z "${PUBLIC_IPS}" ]
then
    echo "ERROR: Reguired envrionment variable(s) missing"
    exit 1
fi

# These environment variables have DEFAULT values if not set
[ -z "${DAO_STORAGE_FILE}" ] && DAO_STORAGE_FILE="ansible/contracts/sc_dao/Storage.txt"
[ -z "${DAO_RUNTIME_BIN_FILE}" ] && DAO_RUNTIME_BIN_FILE="ansible/contracts/sc_dao/ValidatorSmartContractAllowList.bin-runtime"
[ -z "${DIST_CONTRACT_ARCHIVE_DIR}" ] && DIST_CONTRACT_ARCHIVE_DIR="ansible/contracts/sc_lockup"
[ -z "${DIST_RUNTIME_BIN_FILE}" ] && DIST_RUNTIME_BIN_FILE="ansible/contracts/sc_lockup/Distribution.bin-runtime"
[ -z "${DIST_STORAGE_FILE}" ] && DIST_STORAGE_FILE="ansible/contracts/sc_lockup/Distribution.txt"
[ -z "${DISTRIBUTION_OWNER_ADDRESS_FILE}" ] && DISTRIBUTION_OWNER_ADDRESS_FILE="ansible/keys/distributionOwner/address"
[ -z "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] && LOCKUP_CONTRACT_ARCHIVE_DIR="ansible/contracts/sc_lockup"
[ -z "${LOCKUP_OWNER_ADDRESS_FILE}" ] && LOCKUP_OWNER_ADDRESS_FILE="ansible/keys/lockupOwner/address"
[ -z "${LOCKUP_RUNTIME_BIN_FILE}" ] && LOCKUP_RUNTIME_BIN_FILE="ansible/contracts/sc_lockup/Lockup.bin-runtime"
[ -z "${LOCKUP_STORAGE_FILE}" ] && LOCKUP_STORAGE_FILE="ansible/contracts/sc_lockup/Lockup.txt"


# If the INVENTORY_FILE contains a '/', then create the parent directory if it doesn't exists
[ -z "${INVENTORY_FILE##*/*}" ] && [ ! -d ${INVENTORY_FILE%/*} ] && mkdir -p ${INVENTORY_FILE%/*}

# Create directories that don't exist
[ -d "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] || mkdir -p ${LOCKUP_CONTRACT_ARCHIVE_DIR}
[ -d "${DIST_CONTRACT_ARCHIVE_DIR}" ] || mkdir -p ${DIST_CONTRACT_ARCHIVE_DIR}

BASE_KEYS_DIR='ansible/keys'
NOW=$(date +%s)
NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

is_rpc_ip() {
  [ -z "${RPC_IPS##*$1*}" ]
}

is_validator_ip() {
  [ -z "${VALIDATOR_IPS##*$1*}" ]
}

goquorum_enode_list() {
  INDENTATION=$1
  LAST_IP=${VALIDATOR_IPS##* }
  COMMA=','
  for IP in ${VALIDATOR_IPS}; do
    # Set the comma to an empty sting for the last line.
    [ -z "${IP/$LAST_IP}" ] && COMMA=''
    printf '%*s\"enode://{{ custom_validator_pub_%s }}@%s:{{ goquorum_p2p_port }}\"%s\n' $INDENTATION '' ${IP//[.]/_} ${IP} ${COMMA}
  done
}

goquorum_import_private_key() {
  is_validator_ip $1 && echo 'true' && return
  echo 'false'
}

nodekey_keydir() {
  is_validator_ip $1 && echo "keys/$1" && return
  echo '.'
}

node_type_for_ip() {
  is_rpc_ip $1 && echo 'rpc' && return
  is_validator_ip $1 && echo 'validator' && return
  echo 'tbd'
}

node_command_line_flags() {
  if is_rpc_ip $1; then echo '--http -http.addr --http.port --http.corsdomain --http.vhosts --http.api'; fi
  if is_validator_ip $1; then echo '--mine --emitcheckpoints --miner.threads --miner.etherbase'; fi
}

# The parameter is the number of spaces to indent the lines
node_validator_pubs() {
  INDENTATION=$1
  for IP in ${VALIDATOR_IPS}; do
    # TBD - Must figuure out where to get the public key
    printf '%*scustom_validator_pub_%s: "%s"\n' $INDENTATION '' ${IP//[.]/_} $(cat ${BASE_KEYS_DIR}/${IP}/nodekey_pub)
  done
}

playbook_section() {
    IP_ADDRESS=$1
    NODE_TYPE=$(node_type_for_ip ${IP_ADDRESS})
    NODE_CMD_LINE_FLAGS=$(node_command_line_flags ${IP_ADDRESS})
    cat << EOF
- name: Quorum install
  hosts: ${IP_ADDRESS}
  connection: ssh
  force_handlers: True
  roles:
    - role: ansible-role-lace
      vars:
        custom_net_env: ${NETWORK_ENVIRONMENT}
        custom_net_name: ${NETWORK_NAME}
        custom_net_id: ${NETWORK_ID}

        # The following cmd line flags are set when custom_node_type is ${NODE_TYPE}:
        #   ${NODE_CMD_LINE_FLAGS}
        custom_node_type: "${NODE_TYPE}"

$(node_validator_pubs 8)

        # Custom networking config params
        custom_p2p_port: 40111

        custom_host_ip: "${IP_ADDRESS}"

        goquorum_enode_list: [
$(goquorum_enode_list 12)
        ]

        # Custom genesis params
        custom_genesis_gaslimit: 0xB71B00
        custom_genesis_gastarget: 0
        custom_genesis_blockperiodseconds: 12
        custom_genesis_trans_emptyblockperiodseconds_block: 20
        custom_genesis_trans_emptyblockperiodseconds: 60
        custom_genesis_filename: "genesis.json"
        custom_gasprice: 2

        #custom_metrics_host: "0.0.0.0" 
        #custom_metrics_port: 9669

        # Secure custom config params
        secure_custom_nodekey_keydir: "$(nodekey_keydir ${IP_ADDRESS})"
        secure_custom_nodekey_filename: "nodekey"
        secure_custom_nodekey_file_src: "{{ secure_custom_nodekey_keydir }}/{{ secure_custom_nodekey_filename }}"

        goquorum_nodekey_file_src: "{{ secure_custom_nodekey_file_src }}"
        goquorum_nodekey_file: "{{ goquorum_geth_dir }}/{{ secure_custom_nodekey_filename }}"

        # Genesis params
        goquorum_genesis_timestamp: ${NOW_IN_HEX}

        goquorum_genesis_gaslimit: "{{ custom_genesis_gaslimit }}"
        goquorum_genesis_blockperiodiseconds: "{{ custom_genesis_blockperiodseconds }}"

        goquorum_genesis_trans_emptyblockperiodseconds_block: "{{ custom_genesis_trans_emptyblockperiodseconds_block }}"
        goquorum_genesis_trans_emptyblockperiodseconds: "{{ custom_genesis_trans_emptyblockperiodseconds }}"

        # User and group
        goquorum_user: service
        goquorum_group: "nogroup"
        goquorum_architecture: "linux"
        goquorum_env_opts: []
        # default to use the private ip in cloud, set this to true to use the public ip
        goquorum_discovery_public_ip: "false"
        # internal state to maintain idempotency
        goquorum_state_updates: []

        # Version to install
        goquorum_version: v22.7.2
        goquorum_download_url: "https://artifacts.consensys.net/public/go-quorum/raw/versions/{{ goquorum_version }}/geth_{{ goquorum_version }}_{{ goquorum_architecture }}_amd64.tar.gz"

        # Directory paths
        goquorum_base_dir: "/var/.lace"
        goquorum_install_dir: "{{ goquorum_base_dir }}/goquorum-{{ goquorum_version }}"
        goquorum_current_dir: "{{ goquorum_base_dir }}/current"
        goquorum_node_private_key_file: "" # JS: I don't think we need this
        goquorum_data_dir: "{{ goquorum_base_dir }}/data"
        goquorum_geth_dir: "{{ goquorum_data_dir }}/geth"
        goquorum_keystore_dir: "{{ goquorum_data_dir }}/keystore"
        goquorum_log_dir: "/var/log/.lace"
        goquorum_ipc_file: "{{ goquorum_base_dir }}/geth.ipc"
        goquorum_profile_file: "/etc/profile.d/goquorum-path.sh"
        goquorum_genesis_file: "{{ custom_genesis_filename }}"
        goquorum_genesis_path: "{{ goquorum_data_dir }}/{{ goquorum_genesis_file }}"

        goquorum_static_nodes_file: "static-nodes.json"

        # Managed service config
        goquorum_managed_service: true
        goquorum_systemd_state: restarted
        goquorum_systemd_file: "goquorum.service"
        goquorum_systemd_dir: "/etc/systemd/system"
        goquorum_init_database: "true"

        # Secure files...
        goquorum_import_private_key: "$(goquorum_import_private_key ${IP_ADDRESS})"

        # goquorum config file args
        goquorum_network_id: "{{ custom_net_id }}"
        goquorum_sync_mode: full
        goquorum_consensus_algorithm: "qbft"
        goquorum_http_host: "0.0.0.0"
        goquorum_http_port: 8669
        goquorum_http_api: ["eth", "net","web3", "quorum", "{{ goquorum_consensus_algorithm }}"]
        goquorum_http_cors_origins: ["*"]
        goquorum_http_virtual_hosts: ["*"]
        goquorum_no_discovery: "true"
        goquorum_p2p_port: "{{ custom_p2p_port }}"
        goquorum_identity: "{{ custom_net_name }}_${IP_ADDRESS}" # Unique identity per brand

        ## CLI args
        # --nat extip:{{ goquorum_host_ip }}
        goquorum_host_ip: "{{ custom_host_ip }}"
        goquorum_default_ip: "127.0.0.1"
        # --verbosity # 0=silent, 1=error, 2=warn, 3=info, 4=debug, 5=detail
        goquorum_log_verbosity: 2
        # --mine --minerthreads 1 --emitcheckpoints \          goquorum_miner_enabled: "true" WARNING!!!!
        goquorum_miner_threads: 1
        goquorum_miner_etherbase: 0
        goquorum_miner_gasprice: "{{ custom_gasprice }}"
        goquorum_miner_gaslimit: "{{ custom_genesis_gaslimit }}"
        goquorum_miner_gastarget: "{{ custom_genesis_gastarget }}"

        ## user defined list of cmd line args as a string
        #goquorum_user_cmdline_args: ""
        #goquorum_env_opts: []
        #goquorum_raft_block_time: 50
        #goquorum_raft_port: 50400
        #goquorum_raft_dns_enable: "true"
        goquorum_ws_enabled: "false"
        #goquorum_ws_host: "127.0.0.1"
        #goquorum_ws_port: 8546
        #goquorum_ws_origins: ["*"]
        #goquorum_ws_api: ["db", "eth","miner", "net", "shh", "txpool","web3", "quorum", "{{ goquorum_consensus_algorithm }}"]
        #goquorum_ws_rpcprefix: "/"
        goquorum_graphql_enabled: "false"
        #goquorum_graphql_virtual_hosts: ["*"]
        #goquorum_graphql_cors_origins: ["*"]
        #goquorum_enable_node_permissions: "true"
        #goquorum_bootnodes: []

        ## --metrics --pprof --pprof.addr 0.0.0.0 --pprof.port 9545 \
        goquorum_metrics_enabled: "false"
        #goquorum_metrics_host: "{{ custom_metrics_host }}" #def: "0.0.0.0"
        #goquorum_metrics_port: "{{ custom_metrics_port }}" # def: 9545)"
        ## --ptm.timeout 5 --ptm.url \$\${QUORUM_PTM_URL} --ptm.http.writebuffersize 4096 --ptm.http.readbuffersize 4096 --ptm.tls.mode off \
        goquorum_ptm_enabled: "false"
        #goquorum_ptm_timeout: 5
        #goquorum_ptm_url: "http://127.0.0.1:9101"
        #goquorum_ptm_http_writebuffersize: 4096
        #goquorum_ptm_http_readbuffersize: 4096
        #goquorum_ptm_tls_mode: "off"
        ## --unlock 0 --password /config/passwords.txt \
        #goquorum_unlock: 0
        #goquorum_account_password_file: ""

        #goquorum_istanbul_request_timeout: 10000
        #goquorum_istanbul_block_period: 12
        #goquorum_istanbul_epoch: 5
        #goquorum_istanbul_ceil2nby3block: 0

        # Smart contract genesis params
        # Smart Contract code

        # lockupOwner:  testnet - one of the "new" wallets created above
        #               mainnet - no entity assigned to this (yet?)
        #                       - this wallet will need to be generated during the key ceremony
        lace_genesis_lockup_owner_address: $(cat $LOCKUP_OWNER_ADDRESS_FILE)

        # lockupIssuer: testnet - address of the testnet distribution smart contract
        #               mainnet - address of the mainnet distribution smart contract
        lace_genesis_lockup_issuer_address: 8Be503bcdEd90ED42Eff31f56199399B2b0154CA
        lace_genesis_lockup_daily_limit: "18289060790000"

        lace_genesis_lockup_last_dist_timestamp: "${NOW_IN_HEX#0x}" # TBD - should it have 0x or not?

        # distributionOwner:  testnet - one of the "new" wallets created above
        #                     mainnet - the brand will receive a wallet generated during the key ceremony that will own the distribution contract
        #                             - the distributionOwner will be the address of this wallet.
        lace_genesis_distribution_owner_address: $(cat $DISTRIBUTION_OWNER_ADDRESS_FILE)

        # distributionIssuer: testnet - the service team already has this wallet, private key in KMS.
        #                             - "Stage distribution wallet address"
        #                     mainnet - nogo will receive a wallet generated during the key ceremony and that wallet address will be set as the distributionIssuer by the distribution owner.
        #                             - this private key will be stored in KMS and is the key that the nodeserver will sign transactions with
        #                             - "Prod distribution wallet address"
        lace_genesis_distribution_issuer_address: e577b7b8ae3f7cc16f2d65dded598bfa83f77ccd
        goquorum_genesis_sc_dao_code: "0x$(cat ${DAO_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_lockup_code: "0x$(cat ${LOCKUP_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_distribution_code: "0x$(cat ${DIST_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_lockup_balance: "1000000000000000000000000000"
        goquorum_genesis_sc_distribution_balance: "2087600000000000000"

        # Smart Contract storage
        goquorum_genesis_sc_dao_storage: {
$(sed -nE '/storage/,/}/ {
  /storage/d ; /}/d ; s/^[[:space:]]+/                        /p
}' $DAO_STORAGE_FILE)
        }

        goquorum_genesis_sc_lockup_storage: {
                "0x0000000000000000000000000000000000000000000000000000000000000000": "{{ lace_genesis_lockup_owner_address }}",
                "0x0000000000000000000000000000000000000000000000000000000000000002": "{{ lace_genesis_lockup_issuer_address }}",
                "0x0000000000000000000000000000000000000000000000000000000000000004": "{{ lace_genesis_lockup_daily_limit }}",
                "0x0000000000000000000000000000000000000000000000000000000000000005": "{{ lace_genesis_lockup_last_dist_timestamp }}"
        }

        goquorum_genesis_sc_distribution_storage: {
                "0x0000000000000000000000000000000000000000000000000000000000000000": "{{ lace_genesis_distribution_owner_address }}",
                "0x0000000000000000000000000000000000000000000000000000000000000001": "{{ lace_genesis_distribution_issuer_address }}",
                "0x0000000000000000000000000000000000000000000000000000000000000002": "47e9fbef8c83a1714f1951f142132e6e90f5fa5d"
        }
EOF
}

echo "---" > ansible/goquorum.yaml
for IP in ${PUBLIC_IPS}; do
  playbook_section $IP >> ansible/goquorum.yaml
done
