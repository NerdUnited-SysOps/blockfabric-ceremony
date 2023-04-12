#!/usr/bin/env zsh

set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)
ETHKEY=${HOME}/go/bin/ethkey

usage() {
	echo "This script is a helper for deploying bridge smart contracts"
    echo "Usage: $0 (options) ..."
    echo "  -f : Path to .env file"
    echo "  -i : Install dependencies"
    echo "  -r : Reset the ceremony"
    echo "  -h : Help"
    echo ""
    echo "Example: "
}

while getopts 'b:d:f:hi' option; do
	case "$option" in
		f)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		i)
			${SCRIPTS_DIR}/install_dependencies.sh
			exit 0
			;;
		r)
			${SCRIPTS_DIR}/reset.sh
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

[ -z "${APPROVER_ADDRESS_FILE}" ] && APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume3/approver"
[ -z "${NOTARY_ADDRESS_FILE}" ] && NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume2/notary"
[ -z "${TOKEN_OWNER_ADDRESS_FILE}" ] && TOKEN_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume2/token_owner"
[ -z "${TOKEN_CONTRACT_ADDRESS_FILE}" ] && TOKEN_CONTRACT_ADDRESS_FILE="$BASE_DIR/tmp/token_contract_address"

echo "file: ${APPROVER_ADDRESS_FILE}/keystore" &>> ${LOG_FILE}

check_file() {
	file_name=$1
	file_path=$2

	if [ ! -f "${file_path}" ]; then
		printer -e "Missing ${file_name}. Expected it here: ${file_path}"
	fi
}

check_wallet_files() {
    check_file "Approver address"  "${APPROVER_ADDRESS_FILE}/keystore"
    check_file "Notary address"  "${NOTARY_ADDRESS_FILE}/keystore"
    check_file "Token address"  "${TOKEN_OWNER_ADDRESS_FILE}/keystore"
}

get_address() {
    keystore_path=$1
    ADDRESS="0x$(grep -o '"address": *"[^"]*"' ${keystore_path} | grep -o '"[^"]*"$' | sed 's/"//g')"
    echo $ADDRESS
}

get_deployer_a_private_key() {
    keystore=$(${SCRIPTS_DIR}/get_aws_key.sh "${AWS_DISTIRBUTION_ISSUER_KEYSTORE}")
    keystore_file_path=./tmp/issuer_keystore
    mkdir -p ./tmp

    echo "${keystore}" > ${keystore_file_path}

    password=$(${SCRIPTS_DIR}/get_aws_key.sh "${AWS_DISTIRBUTION_ISSUER_PASSWORD}")

    inspected_content=$(${ETHKEY} inspect --private --passwordfile <(echo "${password}") "${keystore_file_path}")
    echo "${inspected_content}" | sed -n "s/Private\skey:\s*\(.*\)/\1/p" | tr -d '\n'
}

 deploy_bridge() {
    DEPLOYER_CMD=cmd
    printer -n "Deploying L2 Bridge"
    # Deploy bridge
    go run ${DEPLOYER_CMD}/bridge/main.go \
         ${NERD_CHAIN_URL} \
         $1 \
         $2 \
         $3 \
         ${FEE_RECEIVER} \
         ${DEPLOYMENT_FEE} \
        ${CHAIN_ID}

    mkdir -p ${BASE_DIR}/tmp
    mv bridge_address ${BASE_DIR}/tmp

    printer -n "L2 Bridge Deployed."
 }

 deploy_token() {
    # Deploy Token

    deployer_a_private_key=$3
    printer -n "Deploying L1 ERC20 Token"
    go run ${DEPLOYER_CMD}/token/main.go \
        ${ETH_URL} \
        $1 \
        ${TOKEN_NAME} \
        ${TOKEN_SYMBOL} \
        ${TOKEN_DECIMALS} \
        ${TOKEN_MAX_SUPPLY} \
        $2                  \
        $deployer_a_private_key

    mv token_contract_address ${BASE_DIR}/tmp/token_contract_address

 }

 deploy_bridge_minter() {
    # Deploy Bridge Minter
    printer -n "Deploying L1 Bridge Minter"
    go run ${DEPLOYER_CMD}/bridge_minter/main.go \
        ${ETH_URL} \
        $1 \
        $2 \
        $3 \
        $4 \
        ${CHAIN_ID}

    mv bridge_minter_address ${BASE_DIR}/tmp/bridge_minter_address
 }

deploy_bridge_contracts() {

    deployer_a_private_key=$(get_deployer_a_private_key)
    deployer_b_private_key=$(${SCRIPTS_DIR}/get_aws_key.sh "${DEPLOYER_B_KEY_NAME}")

    approver_address=$(get_address $APPROVER_ADDRESS_FILE/keystore)
    notary_address=$(get_address $NOTARY_ADDRESS_FILE/keystore)
    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE/keystore)

    git config --global url."https://${GITHUB_PAT}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

    export GOPRIVATE=github.com/NerdCoreSdk/*

    cd bridge_deployer

    go get github.com/NerdCoreSdk/neptune/pkg/contracts

    export DEPLOYER_CMD=cmd

    deploy_bridge $deployer_a_private_key $approver_address $notary_address
    deploy_token $deployer_b_private_key $token_owner_address $deployer_a_private_key
    token_contract_address=$(cat $TOKEN_CONTRACT_ADDRESS_FILE)
    deploy_bridge_minter $deployer_a_private_key $approver_address $notary_address $token_contract_address

    printer -n "Deploying finished."
}

configure_go() {
    git config --global url."https://${GITHUB_PAT}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

    export GOPRIVATE=github.com/NerdCoreSdk/*

    cd bridge_deployer

    go get github.com/NerdCoreSdk/neptune/pkg/contracts

    export DEPLOYER_CMD=cmd
}

deploy_l2_bridge_contract() {
    check_wallet_files

    deployer_a_private_key=$(get_deployer_a_private_key)

    approver_address=$(get_address $APPROVER_ADDRESS_FILE/keystore)
    notary_address=$(get_address $NOTARY_ADDRESS_FILE/keystore)

    configure_go

    deploy_bridge $deployer_a_private_key $approver_address $notary_address
    cd -

    printer -n "Deployed L2 bridge."
}

deploy_l1_token_contract() {
    check_wallet_files
    deployer_a_private_key=$(get_deployer_a_private_key)
    deployer_b_private_key=$(${SCRIPTS_DIR}/get_aws_key.sh "${DEPLOYER_B_KEY_NAME}")

    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE/keystore)

    configure_go

    deploy_token $deployer_b_private_key $token_owner_address $deployer_a_private_key
    cd -

    printer -n "Deployed L1 contract."
}

deploy_l1_bridge_minter_contract() {
    check_wallet_files
    deployer_a_private_key=$(get_deployer_a_private_key)

    approver_address=$(get_address $APPROVER_ADDRESS_FILE/keystore)
    notary_address=$(get_address $NOTARY_ADDRESS_FILE/keystore)
    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE/keystore)

    configure_go

    token_contract_address=$(cat $TOKEN_CONTRACT_ADDRESS_FILE)
    deploy_bridge_minter $deployer_a_private_key $approver_address $notary_address $token_contract_address
    cd -

    printer -n "Deployed L1 bridge_minter."
}

items=(
	"Deploy L2 Bridge"
	"Deploy L1 Token"
	"Deploy L1 Bridge Minter"
	"Exit"
)

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"${BRAND_NAME} ${NETWORK_TYPE} | Select option: "
	select item in "${items[@]}"
		case $REPLY in
			1) deploy_l2_bridge_contract; break;;
			2) deploy_l1_token_contract; break;;
			3) deploy_l1_bridge_minter_contract; break;;
			4) printf "Closing\n\n"; exit 1;;
			*)
				printf "\n\nOops, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

# EOF
