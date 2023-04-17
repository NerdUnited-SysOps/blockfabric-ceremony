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

if [ ! "${DEV}" = true ]; then
	${SCRIPTS_DIR}/get_secrets.sh | tee -a ${LOG_FILE}
	${SCRIPTS_DIR}/install_dependencies.sh | tee -a ${LOG_FILE}
fi

${SCRIPTS_DIR}/deploy_bridge_contracts.sh #>> ${LOG_FILE}

# EOF
