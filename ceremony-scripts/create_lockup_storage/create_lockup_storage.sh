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

set -x
SCRIPT_DIR=$(realpath $(dirname $0))

VOL=${VOLUMES_DIR}/volume2/lockupAdmins

addresses=$(ls $VOL)

cd ${SCRIPT_DIR} > /dev/null

npm i &>> ${LOG_FILE}

node ${SCRIPT_DIR}/createStorage.js $addresses

cd - > /dev/null

