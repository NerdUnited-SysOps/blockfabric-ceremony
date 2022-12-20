#!/usr/bin/zsh

set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)

usage() {
	echo "Options"
	echo "  -e : Envifonment config file"
	echo "  -h : This help message"
}

while getopts e:hd option; do
	case "${option}" in
		d) DEV_ENABLED="true";;
		e) ENV_FILE=${OPTARG};;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	printer -e "Missing .env file. Expected it here: ${ENV_FILE}"
else
	source ${ENV_FILE}
fi

usage() {
	printf "This is an interface for validation of the ceremony.\n"
	printf "You may select from the options below\n\n"
}

create_blockchain() {
	${SCRIPTS_DIR}/create_blockchain.sh
}

run_validation() {
	./validation.sh
}

persistence() {
	./persistence.sh
}

# #############################
# Fun
# #############################

print_logo() {
	gradient=$(shuf -i 1-100 -n 1)
	ceremony-scripts/printer.sh -f "${gradient}"
	printf "\n\n"
}

dev() {
	${SCRIPTS_DIR}/dev.sh
}

items=(
	"Create blockchain"
	"Run validation"
	"Persist assets"
	"Print beautiful logo"
	"Exit"
)

[ -n "${DEV_ENABLED}" ] && items+=("Devz")

clear -x

usage

NC='\033[0m'
RED='\033[0;31m'
while true; do
	COLUMNS=1
	PS3=$'\n'"Select option: "
	select item in "${items[@]}" 
		case $REPLY in
			1) clear -x; create_blockchain; break;;
			2) clear -x; run_validation; break;;
			3) clear -x; persistence; break;;
			4) clear -x; print_logo; break;;
			5) printf "Closing\n\n"; exit 1;;
			6) clear -x; dev; break;;
			*) 
				printf "\n\nOoos, ${RED}${REPLY}${NC} is an unknown option\n\n";
				usage
				break;
		esac
	done
done

