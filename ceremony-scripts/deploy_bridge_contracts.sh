#!/usr/bin/zsh
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

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

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
	inspect_path=$1
	inspected_content=$(${ETHKEY} inspect \
		--private \
		--passwordfile ${inspect_path}/password \
		${inspect_path}/keystore)
	echo "${inspected_content}" | sed -n "s/Address:\s*\(.*\)/\1/p" | tr -d '\n'
}


deploy_bridge_contracts() {
    printer -t "Deploying bridge contracts"
	${SCRIPTS_DIR}/deploy_bridge_contracts.sh >> ${LOG_FILE}
    printer -s "Finished deploying bridge contracts"

    printer -t "Deploying bridge smart contracts"
    printer -w "TODO: Fixup smart contract deployment with updated go app"

    bridge_approver_address=$(get_address $BRIDGE_APPROVER_ADDRESS_FILE)
    bridge_notary_address=$(get_address $BRIDGE_NOTARY_ADDRESS_FILE)
    bridge_fee_receiver_address=$(get_address $BRIDGE_FEE_RECEIVER_ADDRESS_FILE)
    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE)
    bridge_minter_approver_address=$(get_address $BRIDGE_MINTER_APPROVER_ADDRESS_FILE)
    bridge_minter_notary_address=$(get_address $BRIDGE_MINTER_NOTARY_ADDRESS_FILE)

    echo $bridge_approver_address
    echo $bridge_notary_address
    echo $bridge_fee_receiver_address
    echo $token_owner_address
    echo $bridge_minter_approver_address
    echo $bridge_minter_notary_address
    printer -s "Finished deploying bridge smart contracts"
    exit
    export GOPRIVATE=github.com/elevate-blockchain/*

    cd bridge_deployer

    go get github.com/elevate-blockchain/neptune/pkg/contracts

    // Deploy bridge
    go run bridge/main.go
        ${NERD_CHAIN_URL}
        ${DEPLOYER_PRIVATE_KEY}
        ${bridge_approver_address}
        ${bridge_notary_address}
        ${bridge_fee_receiver_address}
        ${DEPLOYMENT_FEE}
        ${CHAIN_ID}

    token_issuer_address=0x3245342435345 # TODO - Determine this address

    // Deploy Token
    token_contract_address = $(go run token/main.go
        ${NERD_CHAIN_URL}
        ${DEPLOYER_PRIVATE_KEY}
        ${TOKEN_NAME}
        ${TOKEN_SYMBOL}
        ${TOKEN_DECIMALS}
        ${token_owner_address}
        ${token_issuer_address}
        ${DEPLOYMENT_FEE}
    )

    // Deploy Bridge Minter
    go run bridge_minter/main.go
        ${ETH_URL}
        ${DEPLOYER_PRIVATE_KEY}
        ${bridge_approver_address}
        ${bridge_notary_address}
        ${token_contract_address}
        ${CHAIN_ID}
}


check_wallet_files
deploy_bridge_contracts


# EOF
