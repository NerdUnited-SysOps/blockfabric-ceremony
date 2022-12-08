#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/../.common.sh

${SCRIPTS_DIR}/printer.sh -t "Generating lockup admin wallets"

VOL1=${VOLUMES_DIR}/volume1/lockupAdmins
VOL2=${VOLUMES_DIR}/volume2/lockupAdmins

echo 'started'

# read -r z b <<<$(~/go/bin/ethkey inspect --private --passwordfile <(echo "") $(~/go/bin/geth account new --password <(echo "") &> log | sed -n -e 's/.*f the secret key file: //p') | grep 'Address\|Private' | sed -n -e 's/.*:\ *//p' | tr '\n' ' ')
# echo "Finished: z: ${z} b: ${b}"
# exit

mkdir -p ${VOL1} ${VOL2}
WORKING_DIR=${VOL1}

create_key2() {
	password=$(pwgen -c 25 -n 1)

	account_path=$(geth account new --password < <(echo "${password}") &> log | sed -n -e 's/.*f the secret key file: //p')
	echo "account_path: ${account_path}"
	address=$(ethkey inspect \
		--private \
		--passwordfile <(echo "${password}") ${account_path} \
		| grep 'Address' \
		| sed -n -e 's/.*:\ *//p')
	echo "address: ${address}"

		# | grep 'Address\|Private' \
    echo $privatekey > ${VOL1}/$address
    echo $privatekey > ${VOL2}/$address
}

for i in {1..2}
do
	create_key2 $i &
	if (( $i % 10 == 0 ))
	then
		${SCRIPTS_DIR}/printer.sh -n "Generated ${i} lockup admin wallets so far"
	fi
done
wait

${SCRIPTS_DIR}/printer.sh -s "Generated lockup admin wallets"

