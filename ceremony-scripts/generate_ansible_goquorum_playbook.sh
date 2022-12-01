#!/bin/bash
#
#===================================================================================
#
# FILE: generate_ansible_goquorum_laybook.sh
#
# USAGE: generate_ansible_goquorum_laybook.sh -v [Validator IP String] -r [RPC IP String]
#
# DESCRIPTION: List and/or delete all stale links in directory trees.
# The default starting directory is the current directory.
# Don’t descend directories on other filesystems.
#
# OPTIONS: see function ’usage’ below
# REQUIREMENTS: ---
# BUGS: ---
# NOTES: ---
# AUTHOR:
# COMPANY:
# VERSION: v0.0.1
# CREATED:
# REVISION:
#===================================================================================
#
# This script REQUIRES various environment variables to be set.
# For some of them, try to calculate them from other environment variables.
#

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

# Environment Vars
ENV_NETWORK=testnet
ENV_NETWORK_ID="2666328"
ENV_NETWORK_NAME=WinTestnet

NETWORK_LAUNCH_DATE="221001"
NETWORK_DAILY_LIMIT_WEI_HEX="0x18556a6b879e00"
NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX="0x4563918244f40000"
NETWORK_ISSUER_GAS_SEED_WEI_HEX="0x5d21dba00"

LOCKUP_SC_BALANCE=$(($NETWORK_TOTAL_COIN_SUPPLY_WEI_HEX-${NETWORK_ISSUER_GAS_SEED_WEI_HEX}))
ISSUER_GAS_SEED_WEI=$(printf '%d\n' ${NETWORK_ISSUER_GAS_SEED_WEI_HEX})
NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

PROJECT_DIR=$SCRIPT_DIR
VALIDATOR_IPS=""
RPC_IPS=""
## Let's do some admin work to find out the variables to be used here
BOLD='\e[1;31m'         # Bold Red
REV='\e[1;32m'       # Bold Green

function help {
	echo -e "${REV}Basic usage:${OFF} ${BOLD}$SCRIPT -v <"value"> -r <"value"> [--longopt[=]<value>] command ${OFF}"\\n
	echo -e "${REV}The following switches are recognized. $OFF "
	echo -e "${REV}-v                   ${OFF}Validator Node IP List"
	echo -e "${REV}-r                   ${OFF}RPC Node IP List"
	echo -e "${REV}--longopt[=]<value>  ${OFF}Description"
	echo -e "${REV}-h                   ${OFF}Displays this help message. No further functions are performed."\\n
	exit 1
}


# In case you wanted to check what variables were passed
#echo "flags = $*"

OPTSPEC=":hv:r:-:"
while getopts "$OPTSPEC" optchar; do
	case "${optchar}" in
		-)
			case "${OPTARG}" in
				longopt)
					val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
					echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
					;;
				longopt=*)
					val=${OPTARG#*=}
					opt=${OPTARG%=$val}
					echo "Parsing option: '--${opt}', value: '${val}'" >&2
					;;
				*)
					if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
						echo "Unknown option --${OPTARG}" >&2
					fi
					;;
			esac
			;;
		v)
            VALIDATOR_IPS+=$OPTARG
			;;
		r)
			RPC_IPS=$OPTARG
			;;
        :)
            echo "Error: -${OPTARG} requires an argument."
            help
            ;;
		h)
			help
			;;
		\?) #unrecognized option - show help
			echo -e "\nOption -${BOLD}$OPTARG${OFF} not allowed.\n"
			help
			;;
	esac
done

shift "$(( OPTIND - 1 ))"

if [ -z "$RPC_IPS" ] && [ -z "$VALIDATOR_IPS" ]; then
        echo 'Missing -v and -r' >&2
        help
        exit 1
fi

[ -z "${PUBLIC_IPS}" ] && PUBLIC_IPS="${RPC_IPS} ${VALIDATOR_IPS}"

if [ -z "${ENV_NETWORK}" ] || [ -z "${ENV_NETWORK_ID}" ] || [ -z "${ENV_NETWORK_NAME}" ] || [ -z "${PUBLIC_IPS}" ]
then
    echo "ERROR: Required envrionment variable(s) missing"
    exit 1
fi

# These environment variables have DEFAULT values if not set
[ -z "${DAO_CONTRACT_ARCHIVE_DIR}" ] && DAO_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_dao/$DAO_VERSION"
[ -z "${DAO_STORAGE_FILE}" ] && DAO_STORAGE_FILE="$DAO_CONTRACT_ARCHIVE_DIR/Storage.txt"
[ -z "${DAO_RUNTIME_BIN_FILE}" ] && DAO_RUNTIME_BIN_FILE="$DAO_CONTRACT_ARCHIVE_DIR/ValidatorSmartContractAllowList.bin-runtime"
[ -z "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] && LOCKUP_CONTRACT_ARCHIVE_DIR="$BASE_DIR/contracts/sc_lockup/$LOCKUP_VERSION"
[ -z "${DIST_RUNTIME_BIN_FILE}" ] && DIST_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Distribution.bin-runtime"
[ -z "${DIST_OWNER_ADDRESS_FILE}" ] && DIST_OWNER_ADDRESS_FILE="$BASE_DIR/keys/distributionOwner/address"
[ -z "${LOCKUP_OWNER_ADDRESS_FILE}" ] && LOCKUP_OWNER_ADDRESS_FILE="$BASE_DIR/keys/lockupOwner/address"
[ -z "${LOCKUP_RUNTIME_BIN_FILE}" ] && LOCKUP_RUNTIME_BIN_FILE="$LOCKUP_CONTRACT_ARCHIVE_DIR/Lockup.bin-runtime"
[ -z "${ANSIBLE_INSTALL_SCRIPT}" ] && ANSIBLE_INSTALL_SCRIPT="$BASE_DIR/ansible/install"

# Create directories that don't exist
[ -d "${LOCKUP_CONTRACT_ARCHIVE_DIR}" ] || mkdir -p ${LOCKUP_CONTRACT_ARCHIVE_DIR}

BASE_KEYS_DIR=$SCRIPT_DIR/keys
NOW=$(date +%s)
NOW_IN_HEX="$(printf '0x%x\n' ${NOW})"

generate_ansible_galaxy_install_script() {
    if [ ! -f "$ANSIBLE_INSTALL_SCRIPT" ]; then
        echo "#!/usr/bin/env bash" > $ANSIBLE_INSTALL_SCRIPT
        echo "ansible-galaxy install git+https://github.com/NerdUnited-Nerd/ansible-role-lace,$1 --force" >> $ANSIBLE_INSTALL_SCRIPT
    fi
}

is_rpc_ip() {
  [ ! -z "$RPC_IPS" ] && [ -z "${RPC_IPS##*$1*}" ]
}

is_validator_ip() {
  [ ! -z "$VALIDATOR_IPS" ]  && [ -z "${VALIDATOR_IPS##*$1*}" ]
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
        goquorum_identity: "${ENV_NETWORK_NAME}_${ENV_NETWORK}_${IP_ADDRESS}" # Unique identity per brand

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

        lace_genesis_lockup_owner_address: $(cat $LOCKUP_OWNER_ADDRESS_FILE)
        lace_genesis_lockup_issuer_address: 8Be503bcdEd90ED42Eff31f56199399B2b0154CA
        lace_genesis_lockup_daily_limit: "${NETWORK_DAILY_LIMIT_WEI_HEX#0x}"
        lace_genesis_lockup_last_dist_timestamp: "${NOW_IN_HEX#0x}"
        lace_genesis_distribution_owner_address: $(cat $DIST_OWNER_ADDRESS_FILE)
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


echo "---" > ansible/goquorum.yaml
for IP in ${PUBLIC_IPS}; do
  playbook_section $IP >> ansible/goquorum.yaml
done

generate_ansible_galaxy_install_script $ANSIBLE_ROLE_LACE_VERSION
