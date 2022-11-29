#!/bin/bash

# This script REQUIRES various environment variables to be set.
# For some of them, try to calculate them from other environment variables.

# Environment Vars
ENV_NETWORK=testnet
ENV_NETWORK_ID="2666328"
ENV_NETWORK_NAME=WinTestnet

NETWORK_LAUNCH_DATE="221001"
NETWORK_DAILY_LIMIT_WEI_HEX_NOPREFIX=18556a6b879e00
NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX="0x4563918244f40000"
NETWORK_ISSUER_GAS_SEED_WEI_HEX="0x5d21dba00"
ANSIBLE_ROLE_LACE_VERSION=1.0.0.5-test

LOCKUP_SC_BALANCE=$(($NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX-${NETWORK_ISSUER_GAS_SEED_WEI_HEX}))
ISSUER_GAS_SEED_WEI=$(printf '%d\n' ${NETWORK_ISSUER_GAS_SEED_WEI_HEX})
NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

#REMOVE
PUBLIC_IPS=1

#if [ -z "${RPC_IPS}" ]; then
#  if [ -n "${RPC_IPS_FILE}" ]; then
#    RPC_IPS=$(cat ${AWS_RPC_IPS_FILE} | tr "\n" " ")
#  elif [ -n "${AWS_RPC_IPS}" ] && [ -n "${AZURE_RPC_IPS}" ] && [ -n "${GCP_RPC_IPS}" ]; then
#    RPC_IPS="${AWS_RPC_IPS} ${AZURE_RPC_IPS} ${GCP_RPC_IPS}"
#  elif [ -n "${AWS_RPC_IPS_FILE}" ] && [ -n "${AZURE_RPC_IPS_FILE}" ] && [ -n "${GCP_RPC_IPS_FILE}" ]; then
#    RPC_IPS=$(cat ${AWS_RPC_IPS_FILE} ${AZURE_RPC_IPS_FILE} ${GCP_RPC_IPS_FILE} | tr "\n" " ")
#  else
#    echo "ERROR: Reguired envrionment variable(s) missing"
#    exit 1
#  fi
#fi
#
#if [ -z "${VALIDATOR_IPS}" ]; then
#  if [ -n "${VALIDATOR_IPS_FILE}" ]; then
#    VALIDATOR_IPS=$(cat ${AWS_VALIDATOR_IPS_FILE} | tr "\n" " ")
#  elif [ -n "${AWS_VALIDATOR_IPS}" ] && [ -n "${AZURE_VALIDATOR_IPS}" ] && [ -n "${GCP_VALIDATOR_IPS}" ]; then
#    VALIDATOR_IPS="${AWS_VALIDATOR_IPS} ${AZURE_VALIDATOR_IPS} ${GCP_VALIDATOR_IPS}"
#  elif [ -n "${AWS_VALIDATOR_IPS_FILE}" ] && [ -n "${AZURE_VALIDATOR_IPS_FILE}" ] && [ -n "${GCP_VALIDATOR_IPS_FILE}" ]; then
#    VALIDATOR_IPS=$(cat ${AWS_VALIDATOR_IPS_FILE} ${AZURE_VALIDATOR_IPS_FILE} ${GCP_VALIDATOR_IPS_FILE} | tr "\n" " ")
#  else
#    echo "ERROR: Required envrionment variable(s) missing"
#    exit 1
#  fi
#fi

[ -z "${PUBLIC_IPS}" ] && PUBLIC_IPS="${RPC_IPS} ${VALIDATOR_IPS}"

if [ -z "${ENV_NETWORK}" ] || [ -z "${ENV_NETWORK_ID}" ] || [ -z "${ENV_NETWORK_NAME}" ] || [ -z "${PUBLIC_IPS}" ]
then
    echo "ERROR: Required envrionment variable(s) missing"
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
[ -z "${ANSIBLE_INSTALL_SCRIPT}" ] && ANSIBLE_INSTALL_SCRIPT="ansible/install"


# If the INVENTORY_FILE contains a '/', then create the parent directory if it doesn't exists
[ -z "${INVENTORY_FILE##*/*}" ] && [ ! -d ${INVENTORY_FILE%/*} ] && mkdir -p ${INVENTORY_FILE%/*}

# Create directories that don't exist
[ -d "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] || mkdir -p ${LOCKUP_CONTRACT_ARCHIVE_DIR}
[ -d "${DIST_CONTRACT_ARCHIVE_DIR}" ] || mkdir -p ${DIST_CONTRACT_ARCHIVE_DIR}

BASE_KEYS_DIR='ansible/keys'
NOW=$(date +%s)
NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

generate_ansible_galaxy_install_script() {
    if [ ! -f "$ANSIBLE_INSTALL_SCRIPT" ]; then
        echo "#!/usr/bin/env bash" > $ANSIBLE_INSTALL_SCRIPT
        echo "ansible-galaxy install git+https://github.com/NerdUnited-Nerd/ansible-role-lace,$1 --force" >> $ANSIBLE_INSTALL_SCRIPT
    fi
}

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
        # The following cmd line flags are set when custom_node_type is ${NODE_TYPE}:
        #   ${NODE_CMD_LINE_FLAGS}
        goquorum_node_type: "${NODE_TYPE}"
        goquorum_network_id: "${ENV_NETWORK_ID}"
        goquorum_identity: "${ENV_NETWORK_NAME}_${NETWORK_ENV}_${ip}" # Unique identity per brand

$(node_validator_pubs 8)
        # GoQuorum version to install
        goquorum_version: v22.7.2

        # Genesis params
        goquorum_init_database: "true"
        goquorum_genesis_timestamp: ${NOW_IN_HEX}

        ## CLI args
        # --nat extip:{{ goquorum_host_ip }}
        goquorum_host_ip: "${IP_ADDRESS}"

        goquorum_enode_list: [
$(goquorum_enode_list 12)
        ]

      # Secure files
        goquorum_import_private_key: "$(goquorum_import_private_key ${IP_ADDRESS})"
        secure_custom_nodekey_keydir: "$(nodekey_keydir ${IP_ADDRESS})"

        # Preseeding vars
        goquorum_genesis_prealloc_addr_0: "aD8828b5Aa66a0642B925AAA2F6C6Dc6f04dc1a4"
        goquorum_genesis_prealloc_addr_1: "c002dBb8Ce18Cd4d32Bf2F3CEc003696ae10B366"
        goquorum_genesis_prealloc_addr_2: "00Ac05334326CCCe74056E5ed9D144Dece49177A"
        goquorum_genesis_prealloc_addr_3: "c004afcA49dce97d3483Ffa1f46C98874C838477"
        goquorum_genesis_prealloc_addr_4: "85E9a6Ad6e6ECDe0e7CC58321fb63655260EF026"
        goquorum_genesis_prealloc_addr_5: "2471eAc62fDd09f891D7662447B641f679a4b810"
        goquorum_genesis_prealloc_addr_6: "c001A1F72Fb82734908398A30f294EAD7B58CcFf"
        goquorum_genesis_prealloc_addr_7: "06D4140c116fb7682D7c2919E94Bc48f5F43C811"
        goquorum_genesis_prealloc_addr_8: "c003ea2Fcf1EE83bEE2225f18b159ca947084826"
        goquorum_genesis_prealloc_addr_9: "2cCc179c46A512B3c05Da76950c897ea4F116B8f"
        goquorum_genesis_prealloc_amount_wei: 100000000000000

        # Smart contract genesis params
        # lockupOwner:  testnet - one of the "new" wallets created above
        #               mainnet - no entity assigned to this (yet?)
        #                       - this wallet will need to be generated during the key ceremony
        lace_genesis_lockup_owner_address: $(cat $LOCKUP_OWNER_ADDRESS_FILE)

        # lockupIssuer: testnet - address of the testnet distribution smart contract
        #               mainnet - address of the mainnet distribution smart contract
        lace_genesis_lockup_issuer_address: 8Be503bcdEd90ED42Eff31f56199399B2b0154CA
        lace_genesis_lockup_daily_limit: "${NETWORK_DAILY_LIMIT_WEI_HEX#0x}"
        lace_genesis_lockup_last_dist_timestamp: "${NOW_IN_HEX#0x}"

        # distributionOwner:  testnet - one of the "new" wallets created above
        #                     mainnet - the brand will receive a wallet generated during the key ceremony that will own the distribution contract
        #                             - the distributionOwner will be the address of this wallet.
        lace_genesis_distribution_owner_address: $(cat $DISTRIBUTION_OWNER_ADDRESS_FILE)

        # distributionIssuer: testnet - the service team already has this wallet, private key in KMS.
        #                             - "Stage distribution wallet address"
        #                     mainnet - nogo will receive a wallet generated during the key ceremony and that wallet address will be set as the distributionIssuer by the distribution owner.
        #                             - this private key will be stored in KMS and is the key that the nodeserver will sign transactions with
        #                             - "Prod distribution wallet address"
        lace_genesis_distribution_issuer_address: 053db724EDD7248168355ec21526c53Cce87e921
        lace_genesis_distribution_issuer_balance: ${ISSUER_GAS_SEED_WEI}


        goquorum_genesis_sc_dao_code: "0x$(cat ${DAO_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_lockup_code: "0x$(cat ${LOCKUP_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_distribution_code: "0x$(cat ${DIST_RUNTIME_BIN_FILE})"
        goquorum_genesis_sc_lockup_balance: "1000000000000000000000000000"
        goquorum_genesis_sc_lockup_balance: "${LOCKUP_SC_BALANCE}"
        goquorum_genesis_sc_distribution_balance: "2087600000000000000"
        goquorum_genesis_sc_distribution_balance: "0"

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


#echo "---" > ansible/goquorum.yaml
#for IP in ${PUBLIC_IPS}; do
#  playbook_section $IP >> ansible/goquorum.yaml
#done

generate_ansible_galaxy_install_script $ANSIBLE_ROLE_LACE_VERSION
