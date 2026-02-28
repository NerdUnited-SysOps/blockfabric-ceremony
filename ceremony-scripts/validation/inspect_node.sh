#!/usr/bin/env zsh

set -e

usage() {
	echo "Options"
	echo "  -e : Environment config file"
	echo "  -m : Mode (config|genesis)"
	echo "  -h : This help message"
}

while getopts he:m: option; do
	case "${option}" in
		e)
			ENV_FILE=${OPTARG}
			;;
		m)
			MODE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${INVENTORY_PATH}" ]] && echo "${0}:${LINENO} .env is missing INVENTORY_PATH variable" && exit 1
[[ -z "${AWS_NODES_SSH_KEY_PATH}" ]] && echo "${0}:${LINENO} .env is missing AWS_NODES_SSH_KEY_PATH variable" && exit 1
[[ -z "${NODE_USER}" ]] && echo "${0}:${LINENO} .env is missing NODE_USER variable" && exit 1
[[ -z "${MODE}" ]] && echo "${0}:${LINENO} Missing -m flag (config|genesis)" && exit 1

SSH_OPTS=(-q -o LogLevel=quiet -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "${AWS_NODES_SSH_KEY_PATH}")

title() {
	local label=$1
	echo -e "------------------------------------------------------------------"
	echo -e "${label}"
	printf "------------------------------------------------------------------\n\n"
}

# Get first host from an inventory group, resolved to its ansible_host IP
get_first_host() {
	local group=$1
	local host=$(ansible --list-hosts -i ${INVENTORY_PATH} ${group} 2>/dev/null | sed '/:/d ; s/ //g' | head -1)
	[[ -z "${host}" ]] && return

	# Resolve ansible_host (DNS name may point to TLS proxy, not the actual node)
	local resolved=$(ansible-inventory -i ${INVENTORY_PATH} --host "${host}" 2>/dev/null | jq -r '.ansible_host // empty')
	[[ -n "${resolved}" ]] && echo "${resolved}" || echo "${host}"
}

remote_cmd() {
	local host=$1
	shift
	ssh ${SSH_OPTS[@]} "${NODE_USER}@${host}" "$@"
}

# ---------------------------------------------------------------
# Mode: config — show config.toml + systemd unit
# ---------------------------------------------------------------
show_config() {
	local validator_ip=$(get_first_host validators)
	local rpc_ip=$(get_first_host rpc_nodes)

	if [[ -n "${validator_ip}" ]]; then
		title "Validator config.toml  (${validator_ip})"
		remote_cmd "${validator_ip}" "sudo cat /etc/besu/config.toml" 2>/dev/null || echo "(could not read config.toml)"
		printf "\n"

		title "Validator systemd unit  (${validator_ip})"
		remote_cmd "${validator_ip}" "sudo systemctl cat besu" 2>/dev/null || echo "(could not read systemd unit)"
		printf "\n"
	else
		echo "No validators found in inventory"
	fi

	if [[ -n "${rpc_ip}" ]]; then
		title "RPC node config.toml  (${rpc_ip})"
		remote_cmd "${rpc_ip}" "sudo cat /etc/besu/config.toml" 2>/dev/null || echo "(could not read config.toml)"
		printf "\n"

		title "RPC node systemd unit  (${rpc_ip})"
		remote_cmd "${rpc_ip}" "sudo systemctl cat besu" 2>/dev/null || echo "(could not read systemd unit)"
		printf "\n"
	else
		echo "No rpc_nodes found in inventory"
	fi
}

# ---------------------------------------------------------------
# Mode: genesis — show genesis.json (identical on all nodes)
# ---------------------------------------------------------------
show_genesis() {
	local node_ip=$(get_first_host rpc_nodes)
	[[ -z "${node_ip}" ]] && node_ip=$(get_first_host validators)
	[[ -z "${node_ip}" ]] && echo "No hosts found in inventory" && exit 1

	title "genesis.json  (${node_ip})"
	local raw=$(remote_cmd "${node_ip}" "sudo cat /etc/besu/genesis.json" 2>/dev/null)

	if [[ -z "${raw}" ]]; then
		echo "(could not read genesis.json)"
		return
	fi

	# Pretty-print if python3 available locally, otherwise raw output
	echo "${raw}" | python3 -m json.tool 2>/dev/null || echo "${raw}"
	printf "\n"
}

# ---------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------
case "${MODE}" in
	config)  show_config  ;;
	genesis) show_genesis ;;
	*)
		echo "${0}:${LINENO} Unknown mode '${MODE}'. Use -m config or -m genesis"
		exit 1
		;;
esac
