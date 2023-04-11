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

[ -z "${APPROVER_ADDRESS_FILE}" ] && APPROVER_ADDRESS_FILE="$BASE_DIR/volumes/volume3/approver"
[ -z "${NOTARY_ADDRESS_FILE}" ] && NOTARY_ADDRESS_FILE="$BASE_DIR/volumes/volume2/notary"
[ -z "${TOKEN_OWNER_ADDRESS_FILE}" ] && TOKEN_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume2/token_owner"

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
    keystore=$(./ceremony-scripts/get_aws_key.sh "${AWS_DISTIRBUTION_ISSUER_KEYSTORE}")
    keystore_file_path=${VOLUMES_DIR}/volume1/distributionIssuer/keystore
    echo "${keystore}" > ${keystore_file_path}

    password=$(./ceremony-scripts/get_aws_key.sh "${AWS_DISTIRBUTION_ISSUER_PASSWORD}")

    inspected_content=$(ethkey inspect --private --passwordfile <(echo "${password}") "${keystore_file_path}")
    echo "${inspected_content}" | sed -n "s/Private\skey:\s*\(.*\)/\1/p" | tr -d '\n'
}

deploy_bridge_contracts() {
    deployer_a_private_key=$(get_deployer_a_private_key)
    approver_address=$(get_address $APPROVER_ADDRESS_FILE/keystore)
    notary_address=$(get_address $NOTARY_ADDRESS_FILE/keystore)
    token_owner_address=$(get_address $TOKEN_OWNER_ADDRESS_FILE/keystore)

    git config --global url."https://${GITHUB_PAT}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

    export GOPRIVATE=github.com/elevate-blockchain/*

    cd bridge_deployer

    go get github.com/elevate-blockchain/neptune/pkg/contracts

    DEPLOYER_CMD=cmd
    printer -n "Deploying L2 Bridge"
    # Deploy bridge
    bridge_output="$(go run ${DEPLOYER_CMD}/bridge/main.go \
         ${NERD_CHAIN_URL} \
         ${deployer_a_private_key} \
         ${approver_address} \
         ${notary_address} \
         ${FEE_RECEIVER} \
         ${DEPLOYMENT_FEE} \
         ${CHAIN_ID})"

    echo "bridge output=" $bridge_output &>> ${LOG_FILE}
    bridge_address="$(echo $bridge_output | tail -n1)"
    echo $bridge_address > ${VOLUMES_DIR}/volume5/bridge_address

    # Deploy Token
    printer -n "Deploying L1 ERC20 Token"
    token_contract_output="$(go run ${DEPLOYER_CMD}/token/main.go \
        ${ETH_URL} \
        ${DEPLOYER_B_PRIVATE_KEY} \
        ${TOKEN_NAME} \
        ${TOKEN_SYMBOL} \
        ${TOKEN_DECIMALS} \
        ${TOKEN_MAX_SUPPLY} \
        ${token_owner_address})"

    echo "token contract address=" $token_contract_output &>> ${LOG_FILE}
    token_contract_address="$(echo $token_contract_output | tail -n1)"
    echo $token_contract_address > ${VOLUMES_DIR}/volume5/token_address

    # Deploy Bridge Minter
    printer -n "Deploying L1 Bridge"
    bridge_minter_output="$(go run ${DEPLOYER_CMD}/bridge_minter/main.go \
        ${ETH_URL} \
        ${deployer_a_private_key} \
        ${approver_address} \
        ${notary_address} \
        ${token_contract_address} \
        ${CHAIN_ID})"

    bridge_minter_address="$(echo $bridge_minter_output | tail -n1)"
    echo $bridge_minter_address > ${VOLUMES_DIR}/volume5/bridge_minter_address

    printer -n "Deploying finished."
}

check_wallet_files
deploy_bridge_contracts


# EOF
