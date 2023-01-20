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

create_bridge_wallets() {
    printer -t "Creating bridge wallets"
	${SCRIPTS_DIR}/create_bridge_wallets.sh &>> ${LOG_FILE}
    printer -s "Finished creating bridge wallets"
}

deploy_smart_contracts() {
    printer -t "Deploying bridge smart contracts"
    printer -w "TODO: Fixup smart contract deployment with updated go app"
    printer -s "Finished deploying bridge smart contracts"
    exit
    export GOPRIVATE=github.com/elevate-blockchain/*

    cd bridge_deployer

    go get github.com/elevate-blockchain/neptune/pkg/contracts

    go run ../bridge_deployer/cmd/main.go
        http://127.0.0.1:7545
        502c2cac7df7a73197b06e70b5ae1e0f02dfc9edd32aabe8c3c59e58aa4ff52f
        0x306bf6Ea79E4B45713251c9d5e989C987feB8DAb
        0x3A9932f3D23e7991EBC93178e4d4c75C5284d637
        0xA3cA95b98225013b5Ef2804330F40CAA04a4327F
        0xf06360ddAE137941723806131F69f68196b16704
        0x6592c955f86C0539415438Fcd52cF5091FeBB285
        "JBToken"
        "JBT"

    // Deploy bridge
    go run bridge/main.go
        http://127.0.0.1:7545
        f4a6dbc1ca457ad22a9f96c945764f73c10c8cf99320d1344ad5e3107a968b62
        0xc672D7aa15d4FD09A20b830435294C2B4895D122
        0xf4871Ac2898121B71ec21E82d3ecada7bE1EEEB9
        0xDe5364DAc6a533212042A066Dfb8c37FA48F6223

    // Deploy Token
    go run token/main.go
        http://127.0.0.1:7545
        f4a6dbc1ca457ad22a9f96c945764f73c10c8cf99320d1344ad5e3107a968b62
        0xc672D7aa15d4FD09A20b830435294C2B4895D122
        0xf4871Ac2898121B71ec21E82d3ecada7bE1EEEB9
        0xDe5364DAc6a533212042A066Dfb8c37FA48F6223
        0xC5280e85d1b896b0Fbe26dC369CfFa7788817ac1

    // Deploy Bridge Minter
    go run bridge_minter/main.go
        http://127.0.0.1:7545
        f4a6dbc1ca457ad22a9f96c945764f73c10c8cf99320d1344ad5e3107a968b62
        0xc672D7aa15d4FD09A20b830435294C2B4895D122
        0xf4871Ac2898121B71ec21E82d3ecada7bE1EEEB9
        0xDe5364DAc6a533212042A066Dfb8c37FA48F6223
        0xC5280e85d1b896b0Fbe26dC369CfFa7788817ac1

    # TODO: Read bridge/bridge_minter/token addresses and insert them into constructor args
    #
    #[ -z "${DIST_OWNER_ADDRESS_FILE}" ] && DIST_OWNER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/distributionOwner"
    #[ -z "${DIST_ISSUER_ADDRESS_FILE}" ] && DIST_ISSUER_ADDRESS_FILE="$BASE_DIR/volumes/volume5/distributionIssuer"

    #vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_approver
    #vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_notary
    #vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_fee_receiver
    #vol${vol}=${VOLUMES_DIR}/volume${vol}/token_owner
    #vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_minter_notary
    #vol${vol}=${VOLUMES_DIR}/volume${vol}/bridge_minter_approver
}

create_bridge_wallets
deploy_smart_contracts



# EOF
