# Versioning for dependencies
export APT_NODEJS_VERSION=18.10.0+dfsg-6
export APT_NPM_VERSION=9.1.2~ds1-2
export APT_GO_VERSION=2:1.19~1
export APT_JQ_VERSION=1.6-2.1
export APT_PWGEN_VERSION=2.08-2
export APT_AWSCLI_VERSION=1.24.8-1
export ETHKEY_VERSION=v1.10.26
export GETH_VERSION=v1.10.26
export ANSIBLE_ROLE_LACE_VERSION=1.0.0.5-test

# Contract versions
export DAO_VERSION=v0.0.1
export LOCKUP_VERSION=v0.1.0

export CONDUCTOR_NODE_URL=conductor.mainnet.${BRAND_NAME:-nerd}.blockfabric.net

# Common paths to be used throughout the various scripts
export BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
export SCRIPTS_DIR=${BASE_DIR}/ceremony-scripts
export UTIL_SCRIPTS_DIR=${BASE_DIR}/ceremony-scripts/util
export KEYS_DIR=${BASE_DIR}/keys
export CONTRACTS_DIR=${BASE_DIR}/contracts
export VOLUMES_DIR=${BASE_DIR}/volumes
export ANSIBLE_DIR=${BASE_DIR}/../ansible
export LOG_FILE=${BASE_DIR}/log
export ENV_FILE=${BASE_DIR}/.env

# Pathing for additional binaries
export PATH="${HOME}/go/bin:${PATH}"	 # Go binary path

# Interacting with AWS Secrets Manager
# For simplicity, let's use this same Key in AWS Secrets Mgr for retrieving the SSH Key.

export SCP_USER=admin
export INVENTORY_PATH=${ANSIBLE_DIR}/inventory
export REMOTE_INVENTORY_PATH=/opt/blockfabric/inventory

# Output coloring
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Overrides based on the environment
if [ -f .env ]
then
  source .env
else
	echo "Missing .env file"
	echo "This program requires a .env file to run"
	exit 1
fi
