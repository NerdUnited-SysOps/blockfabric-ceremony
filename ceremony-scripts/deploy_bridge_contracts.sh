#!/usr/bin/env zsh
set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)

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

[ -z "${BRIDGE_APPROVER_ADDRESS_FILE}" ] && BRIDGE_APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_approver"
[ -z "${BRIDGE_NOTARY_ADDRESS_FILE}" ] && BRIDGE_NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_notary"
[ -z "${BRIDGE_FEE_RECEIVER_ADDRESS_FILE}" ] && BRIDGE_FEE_RECEIVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_fee_receiver"
[ -z "${TOKEN_OWNER_ADDRESS_FILE}" ] && TOKEN_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/token_owner"
[ -z "${BRIDGE_MINTER_APPROVER_ADDRESS_FILE}" ] && BRIDGE_MINTER_APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_minter_approver"
[ -z "${BRIDGE_MINTER_NOTARY_ADDRESS_FILE}"   ] && BRIDGE_MINTER_NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume5/bridge_minter_notary"

check_file() {
	file_name=$1
	file_path=$2

	if [ ! -f "${file_path}" ]; then
		printer -e "Missing ${file_name}. Expected it here: ${file_path}"
	fi
}

check_wallet_files() {
    check_file "Bridge approver address"  "${BRIDGE_APPROVER_ADDRESS_FILE}/keystore"
    check_file "Bridge notary address"  "${BRIDGE_NOTARY_ADDRESS_FILE}/keystore"
    check_file "Bridge fee receiver address"  "${BRIDGE_FEE_RECEIVER_ADDRESS_FILE}/keystore"
    check_file "Token address"  "${TOKEN_OWNER_ADDRESS_FILE}/keystore"
    check_file "Bridge minter approver address"  "${BRIDGE_MINTER_APPROVER_ADDRESS_FILE}/keystore"
    check_file "Bridge minter notary address"  "${BRIDGE_MINTER_NOTARY_ADDRESS_FILE}/keystore"
}

get_address() {
    keystore_path=$1
    echo "keystore: ${keystore_path}"
    ADDRESS=$(grep -o '"address": *"[^"]*"' ${keystore_path} | grep -o '"[^"]*"$' | sed 's/"//g')
}

deploy_bridge_contracts() {
    printer -t "Deploying bridge smart contracts"

    bridge_approver_address=$(get_address $BRIDGE_APPROVER_ADDRESS_FILE)
    bridge_notary_address=$(get_address $BRIDGE_NOTARY_ADDRESS_FILE)
    bridge_fee_receiver_address=$(get_address $BRIDGE_FEE_RECEIVER_ADDRESS_FILE)
    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE)
    bridge_minter_approver_address=$(get_address $BRIDGE_MINTER_APPROVER_ADDRESS_FILE)
    bridge_minter_notary_address=$(get_address $BRIDGE_MINTER_NOTARY_ADDRESS_FILE)

    git config --global url."https://${GITHUB_PAT}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

    export GOPRIVATE=github.com/elevate-blockchain/*

    cd bridge_deployer

    go get github.com/elevate-blockchain/neptune/pkg/contracts

    DEPLOYER_CMD=cmd
    # Deploy bridge
    # go run ${DEPLOYER_CMD}/bridge/main.go \
    #      ${NERD_CHAIN_URL} \
    #      ${DEPLOYER_PRIVATE_KEY} \
    #      ${bridge_approver_address} \
    #      ${bridge_notary_address} \
    #      ${bridge_fee_receiver_address} \
    #      ${DEPLOYMENT_FEE} \
    #      ${CHAIN_ID}

    # Deploy Token
    token_contract_output="$(go run ${DEPLOYER_CMD}/token/main.go \
        ${ETH_URL} \
        ${DEPLOYER_PRIVATE_KEY} \
        ${TOKEN_NAME} \
        ${TOKEN_SYMBOL} \
        ${TOKEN_DECIMALS} \
        ${TOKEN_MAX_SUPPLY} \
        ${token_owner_address})"
    echo "token contract address=" $token_contract_output
    token_contract_address="$(echo $token_contract_output | tail -n1)"

    # # Deploy Bridge Minter
    go run ${DEPLOYER_CMD}/bridge_minter/main.go \
        ${ETH_URL} \
        ${DEPLOYER_PRIVATE_KEY} \
        ${bridge_approver_address} \
        ${bridge_notary_address} \
        ${token_contract_address} \
        ${CHAIN_ID}

    printer -s "Finished deploying bridge smart contracts"
}

check_wallet_files
deploy_bridge_contracts


# EOF
