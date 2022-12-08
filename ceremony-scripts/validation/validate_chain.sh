#!/bin/env sh

usage() {
  echo "Options"
  echo "  -d : Datadir for the remote geth node"
  echo "  -g : Path to geth binary"
  echo "  -h : This help message"
  echo "  -i : Path to inventory file"
  echo "  -k : Path to the private key"
  echo "  -p : RPC Port"
  echo "  -r : Path to the RPC node"
  echo "  -u : User to ssh with"
}

while getopts d:g:i:k:p:r:u: flag; do
    case "${flag}" in
        d) 
            DATADIR=${OPTARG}
            ;;
        g) 
            GETH_PATH=${OPTARG}
            ;;
        h) 
            usage
            exit 0
            ;;
        i) 
            INVENTORY_PATH=${OPTARG}
            ;;
        k) 
            PRIVATE_KEY_PATH=${OPTARG}
            ;;
        p) 
            RPC_PORT=${OPTARG}
            ;;
        r) 
            RPC_PATH=${OPTARG}
            ;;
        u)
            USER=${OPTARG}
            ;;
        *) 
            usage
            exit 1
            ;;
    esac
done

title() {
    title=$1

    echo -e "---------------------------------------------";
    echo -e "${title}";
    echo -e "---------------------------------------------";
}

get_ips() {
    group=${1:-rpc}

    ansible \
        ${group} \
        --list-hosts \
        -i ${INVENTORY_PATH} | sed '/:/d ; s/ //g' | tr "\n" " " ; echo
}


curl_check() {
    ip=$1

    curl \
        --max-time 5.5 \
        https://${RPC_PATH}/ \
        --connect-to ${RPC_PATH}:${RPC_PORT}:${ip}:${RPC_PORT} &>> ${LOG_FILE}
}

check_https() {
    IP_LIST=$1

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'

    title "HTTPS Status"

    for IP in ${IP_LIST}; do
        result="Checking SSL for ${IP}\t"
        if curl_check ${IP}; then
            result+="${GREEN}Success${NC}"
        else
            result+="${RED}Failure${NC}"
        fi
        printf "$result\n"
    done
}

verify_each() {
    HOST=$1
    read -r -d '' exec_cmd <<- EOM
    'console.log("Gas: " + eth.gasPrice + " Block: " + eth.blockNumber + " Peers: " + net.peerCount)'
EOM

	ssh \
      -q \
      -o LogLevel=quiet \
      -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=no \
      -i ${KEY_PATH} \
      "blockadmin@${HOST}" "
          sudo ${GETH_PATH} attach \
            --datadir ${DATADIR} \
            --exec ${exec_cmd}" | grep -v null | sed "s/^/ IP:\ ${HOST}\t/"
}

verify_group() {
    GROUP=$1

    title "Status of ${GROUP}s"

    for ip in $(get_ips ${GROUP}); do
        verify_each $ip &
    done
    wait
}

verify_blockchain() {
    title "Status of Chain"

    geth_exec_command=$(cat ./remoteValidate.js | sed 's/\"/\\"/g') 

    ssh \
        -o ConnectTimeout=20 \
        -o StrictHostKeyChecking=no \
        -i ${KEY_PATH} \
        "${USER}@${RPC_PATH}" "
            sudo ${GETH_PATH} attach \
                --datadir ${DATADIR} \
                --exec \"${geth_exec_command}\""
}

IP_LIST=$(get_ips)

check_https "${IP_LIST}"
verify_group validator
verify_group rpc
verify_blockchain
