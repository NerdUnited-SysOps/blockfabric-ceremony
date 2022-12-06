# Versioning for dependencies

# Common paths to be used throughout the various scripts
export BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
export SCRIPTS_DIR=${BASE_DIR}/ceremony-scripts
export UTIL_SCRIPTS_DIR=${BASE_DIR}/ceremony-scripts/util
export KEYS_DIR=${BASE_DIR}/keys
export CONTRACTS_DIR=${BASE_DIR}/contracts
export VOLUMES_DIR=${BASE_DIR}/volumes
export ANSIBLE_DIR=${BASE_DIR}/ansible
export LOG_FILE=${BASE_DIR}/log
export ENV_FILE=${BASE_DIR}/.env

export PATH="${HOME}/go/bin:${PATH}"	 # Go binary path
export SCP_USER=admin
export INVENTORY_PATH=${ANSIBLE_DIR}/inventory

# Overrides based on the environment
if [ -f $BASE_DIR/.env ]
then
  source $BASE_DIR/.env
else
	echo "Missing .env file"
	echo "This program requires a .env file to run"
	exit 1
fi
