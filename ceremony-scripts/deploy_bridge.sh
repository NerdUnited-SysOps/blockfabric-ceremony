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
	${SCRIPTS_DIR}/create_bridge_wallets.sh # >> ${LOG_FILE}
    printer -s "Finished creating bridge wallets"
}

deploy_bridge_contracts() {
    printer -t "Deploying bridge contracts"
	${SCRIPTS_DIR}/deploy_bridge_contracts.sh #>> ${LOG_FILE}
    printer -s "Finished deploying bridge contracts"
}


create_bridge_wallets
deploy_bridge_contracts


# EOF
