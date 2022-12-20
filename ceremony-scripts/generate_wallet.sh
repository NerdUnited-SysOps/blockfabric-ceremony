#!/usr/bin/zsh

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
ENV_FILE=${BASE_DIR}/.env
GETH_PATH=${HOME}/go/bin/geth
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
		g)
			GETH_PATH=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		o)
			OUTPUT_DIRS=${OPTARG}
			;;
		s)
			SCRIPTS_DIR=${OPTARG}
			;;
		t)
			TITLE=${OPTARG}
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

password=$(pwgen -c 25 -n 1)

new_account_output=$($GETH_PATH account new --password <(echo "${password}"))
echo new_account_output >> ${LOG_FILE}

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

for i in ${new_parts[@]:1}; do
	mkdir -p $i
	cp "${first_dir}"/keystore ${i}/
	cp "${first_dir}"/password ${i}/
done

