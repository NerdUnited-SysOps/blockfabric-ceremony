#!/usr/bin/env zsh
# Test DAO validator vote-in/vote-out
# Requires: node, npm, ceremony artifacts (volume1/volume2)
# Usage: ./test_dao_voting.sh -e chain.env

set -e

_DAO_SCRIPT_DIR="${0:A:h}"
ENV_FILE=""

# Parse args (strip --besu, handle -e and -o)
args=()
for arg in "$@"; do
  [[ "$arg" == "--besu" ]] && continue
  args+=("$arg")
done
set -- "${args[@]}"

while getopts "e:o:d" option; do
  case "$option" in
    e) ENV_FILE="${OPTARG}" ;;
    o) ;; # ignore -o
    d) ;; # ignore -d
  esac
done

[[ -z "${ENV_FILE}" ]] && echo "Usage: $0 -e <chain.env>" && exit 1
[[ ! -f "${ENV_FILE}" ]] && echo "Error: ${ENV_FILE} not found" && exit 1
source "${ENV_FILE}"

# Resolve paths
CEREMONY_DIR="${ENV_FILE:A:h}"
ARTIFACTS_DIR="${HOME}/ceremony-artifacts/volumes"
DAO_ADDRESS="0x5a443704dd4B594B382c22a083e2BD3090A6feF3"

# Get RPC URL — use first validator for tx propagation reliability
# (non-validator RPC nodes may not propagate txs to validators in Besu QBFT)
RPC_PORT="${BESU_RPC_HTTP_PORT:-8669}"
INVENTORY_PATH="${CEREMONY_DIR}/ceremony-artifacts/ansible-ceremony/inventory"
if [[ -f "${INVENTORY_PATH}" ]]; then
  VALIDATOR_IP=$(grep 'besu-v-1 ' "${INVENTORY_PATH}" | grep -o 'ansible_host=[^ ]*' | cut -d= -f2)
  RPC_URL="http://${VALIDATOR_IP}:${RPC_PORT}"
else
  # Fallback: use IP_ADDRESS_LIST first entry from chain.env
  FIRST_VALIDATOR_IP=$(source "${ENV_FILE}" && echo "${IP_ADDRESS_LIST}" | tr ',' '\n' | head -1 | xargs)
  RPC_URL="http://${FIRST_VALIDATOR_IP:-192.168.3.221}:${RPC_PORT}"
fi

# Check prerequisites
[[ ! -d "${ARTIFACTS_DIR}/volume1" ]] && echo "Error: ceremony artifacts not found at ${ARTIFACTS_DIR}" && exit 1
command -v node >/dev/null 2>&1 || { echo "Error: node not found"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "Error: npm not found"; exit 1; }

# Install ethers.js if needed
TEST_DIR="${_DAO_SCRIPT_DIR}/dao-voting"
if [[ ! -d "${TEST_DIR}/node_modules/ethers" ]]; then
  echo "Installing ethers.js..."
  cd "${TEST_DIR}" && npm install --silent 2>/dev/null
fi

echo "=== DAO Voting Test ==="
echo "  RPC: ${RPC_URL}"
echo "  Chain ID: ${CHAIN_ID}"
echo "  DAO: ${DAO_ADDRESS}"
echo ""

# Run the test
node "${TEST_DIR}/test-vote.mjs" "${RPC_URL}" "${CHAIN_ID}" "${DAO_ADDRESS}" "${ARTIFACTS_DIR}"
