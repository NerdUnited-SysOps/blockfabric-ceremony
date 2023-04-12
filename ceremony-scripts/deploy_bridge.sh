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
		echo "  -d : Run in dev mode (do not get secrets or dependencies)"
    echo "  -h : Help"
    echo ""
    echo "Example: "
}

while getopts 'b:df:hi' option; do
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
		d)
			DEV=true
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

generate_wallet() {
	${SCRIPTS_DIR}/generate_wallet.sh "$@" &>> ${LOG_FILE}
}

create_wallet() {
	wallet_name=$1
	volume=$2
	key_path=${VOLUMES_DIR}/${volume}/${wallet_name}

	generate_wallet -o "${key_path}"

	printer -n "Created ${key_path} wallet"
}

create_bridge_wallets() {
	printer -t "Creating bridge wallets"

	create_wallet "token_owner" "volume2" &
	create_wallet "notary" "volume2" &
	create_wallet "approver" "volume3" &
	wait

	printer -s "Finished creating bridge wallets"
}

deploy_bridge_contracts() {
	printer -t "Deploying bridge contracts"
	${SCRIPTS_DIR}/deploy_bridge_contracts.sh #>> ${LOG_FILE}
	printer -s "Finished deploying bridge contracts"
}

if [ ! "${DEV}" = true ]; then
	${SCRIPTS_DIR}/get_secrets.sh | tee -a ${LOG_FILE}
	${SCRIPTS_DIR}/install_dependencies.sh | tee -a ${LOG_FILE}
fi

create_bridge_wallets | tee -a ${LOG_FILE}
deploy_bridge_contracts

# EOF
