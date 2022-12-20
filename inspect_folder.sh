#!/usr/bin/zsh

set -e

ETHKEY_PATH=${HOME}/go/bin/ethkey
# This should be a directory, which, by convention, will contain a keystore and password file
INSPECT_DIR="./"

usage() {
	echo "Options"
	echo "  -e : Path to geth binary"
	echo "  -h : This help message"
	echo "  -i : Inspect directory"
}

while getopts e:hi: option; do
	case "${option}" in
		e)
			ETHKEY_PATH=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		i)
			INSPECT_DIR=${OPTARG}
			;;
	esac
done

${ETHKEY_PATH} inspect \
	--passwordfile ${INSPECT_DIR}/password \
	${INSPECT_DIR}/keystore

