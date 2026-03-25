#!/usr/bin/env zsh

set -e

usage() {
  echo "This script creates the lockup storage"
  echo "Usage: $0 (options) ..."
  echo "  -e : Path to .env file"
  echo "  -h : Help"
  echo ""
  echo "Example: "
}

while getopts 'b:d:e:hi' option; do
       case "$option" in
               e)
                       ENV_FILE=${OPTARG}
                       ;;
               h)
                       usage
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
       echo "Missing .env file. Expected it here: ${ENV_FILE}"
       exit 1
else
       source ${ENV_FILE}
fi

VOL=${VOLUMES_DIR}/volume2/lockupAdmins

addresses=$(ls $VOL)
addresses_array=(${(f)addresses})

# Generate lockup storage using Go (replaces npm/node createStorage.js)
SCRIPT_DIR=$(realpath $(dirname $0))
GO_CMD_DIR=${SCRIPT_DIR}/../cmd
(cd ${GO_CMD_DIR} && go run ./lockup_storage $addresses_array)

