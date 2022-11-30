# Versioning for dependencies
export GO_VERSION=
export ETHKEY_VERSION=v1.10.26
export GETH_VERSION=v1.10.26
export ANSIBLE_ROLE_LACE_VERSION=

# Contract versions
export SC_LOCKUP_BINARY_VERSION=
export DAO_LOCKUP_BINARY_VERSION=
export LOCKUP_VERSION=v0.1.0
export DAO_VERSION=v0.0.1

export CONDUCTOR_NODE_URL=conductor.mainnet.${BRAND_NAME}.blockfabric.net

# Common paths to be used throughout the various scripts
export BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
export SCRIPTS_DIR=${BASE_DIR}/ceremony-scripts
export KEYS_DIR=${BASE_DIR}/keys
export CONTRACTS_DIR=${BASE_DIR}/contracts
export VOLUMES_DIR=${BASE_DIR}/volumes

# Overrides based on the environment
source .env
