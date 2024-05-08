#!/usr/bin/env zsh

set -e

# This should be a directory, which is where the keystore and password files will go
OUTPUT_DIRS="./"
TITLE="generic wallet"

usage() {
	echo "Options"
	echo "  -a : Put the keystore and password inside a directory of the address"
	echo "  -g : Path to geth binary"
	echo "  -h : This help message"
	echo "  -o : Output directory"
	echo "  -s : Script directory to reference other scripts"
	echo "  -t : Label of what key is being generated"
}

while getopts ae:g:h:o:s:t: option; do
	case "${option}" in
		a)
			ADDRESS_DIR="true"
			;;
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		o)
			OUTPUT_DIRS=${OPTARG}
			;;
		t)
			TITLE=${OPTARG}
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${ZSH_ARGZERO}:${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${GETH_PATH}" ]] && echo ".env is missing GETH_PATH variable" && exit 1
[[ ! -f "${GETH_PATH}" ]] && echo "GETH_PATH environment variable is not a file. Expecting it here ${GETH_PATH}" && exit 1

# These environment variables have DEFAULT values if not set
[ -z "${GETH_PATH}" ] && GETH_PATH="${HOME}/go/bin/geth"

inspect() {
  inspect_path=$1

  ${ETHKEY_PATH} inspect \
    --private \
    --passwordfile ${inspect_path}/password \
    ${inspect_path}/keystore
}

get_private_key() {
  inspect_path=$1
  inspected_content=$(inspect "${inspect_path}")
  echo "${inspected_content}" | sed -n "s/Private\skey:\s*\(.*\)/\1/p" | tr -d '\n'
}

password=$(pwgen -c 25 -n 1)

new_account_output=$($GETH_PATH account new --password <(echo "${password}"))

new_keystore_file_path=$(echo ${new_account_output} | sed -n -e 's/.*secret.*:\ *//p')
address=$(echo ${new_account_output} | sed -n -e 's/.*dress.*:\ *//p')

# Creates an array from a space-separated string
parts=(${(@s: :)OUTPUT_DIRS})
new_parts=$parts

if [[ -n "${ADDRESS_DIR}" ]]; then
	# Append the address to each path in the array
	new_parts=${:-${^parts}/${address}}
fi

new_parts=(${(@s: :)new_parts})

first_dir=${new_parts[1]}

mkdir -p ${first_dir}

mv ${new_keystore_file_path} ${first_dir}/keystore
echo $password > ${first_dir}/password
pk=$(get_private_key ${first_dir})
echo "${pk}" > ${first_dir}/privatekey


for i in ${new_parts[@]:1}; do
	mkdir -p $i
	cp "${first_dir}"/keystore ${i}/
	cp "${first_dir}"/password ${i}/
  cp "${first_dir}"/privatekey ${i}/

done

