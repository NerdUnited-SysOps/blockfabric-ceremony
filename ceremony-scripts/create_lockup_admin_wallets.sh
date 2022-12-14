#!/usr/bin/zsh

SCRIPTS_DIR=$(dirname ${(%):-%N})
VOLUMES_DIR=${SCRIPTS_DIR}/../volumes
ETHKEY_PATH=${HOME}/go/bin/ethkey
GETH_PATH=${HOME}/go/bin/geth
BATCH_SIZE=5
CREATE_NUM=100

usage() {
  echo "Options"
  echo "  -b : How big the batch of async key creations should be"
  echo "  -c : How many keys to create"
  echo "  -e : Path to ethkey binary"
  echo "  -g : Path to geth binary"
  echo "  -h : This help message"
  echo "  -s : Script directory to reference other scripts"
  echo "  -v : Volume directory for where the volumes will be placed"
}

while getopts b:c:e:hv:s: option; do
    case "${option}" in
        b)
            BATCH_SIZE=${OPTARG}
            ;;
        c)
            CREATE_NUM=${OPTARG}
            ;;
        e)
            ETHKEY_PATH=${OPTARG}
            ;;
        g)
            GETH_PATH=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        s)
            SCRIPTS_DIR=${OPTARG}
            ;;
        v)
            VOLUMES_DIR=${OPTARG}
            ;;
    esac
done

${SCRIPTS_DIR}/printer.sh -t "Generating lockup admin wallets"

VOL1=${VOLUMES_DIR}/volume1/lockupAdmins
VOL2=${VOLUMES_DIR}/volume2/lockupAdmins

mkdir -p ${VOL1} ${VOL2}
WORKING_DIR=${VOL1}

create_key() {
	password=$(pwgen -c 25 -n 1)

	account_path=$($GETH_PATH account new --password <(echo "${password}") &>> log | sed -n -e 's/.*f the secret key file: //p')
	address=$($ETHKEY_PATH inspect \
		--private \
		--passwordfile <(echo "${password}") ${account_path} \
		| grep 'Address' \
		| sed -n -e 's/.*:\ *//p')

    echo $privatekey > ${VOL1}/$address
    echo $privatekey > ${VOL2}/$address
}

for i in {1..$CREATE_NUM}
do
	create_key $i &
	if (( $i % $BATCH_SIZE == 0 ))
	then
		wait
		${SCRIPTS_DIR}/printer.sh -n "Generated ${i} lockup admin wallets so far"
	fi
done
wait

${SCRIPTS_DIR}/printer.sh -s "Generated ${CREATE_NUM} lockup admin wallets"

