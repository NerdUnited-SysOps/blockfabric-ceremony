#!/usr/bin/zsh

set -e

usage() {
	echo "This script is a helper for printing text"
	echo "Only one argument will be respected"
	echo "Usage: $0 (options) ..."
	echo "  -e : Error message - this will exit with a non-zero code"
	echo "  -f : Print finally"
	echo "  -h : Help"
	echo "  -n : Note message"
	echo "  -s : Success message"
	echo "  -t : Title message"
	echo "  -w : Warning message"
	echo ""
	echo "Example: printer.sh -t \"This is a title\""
	echo "Example: printer.sh -e \"This is an error\""
	echo "Example: printer.sh -s \"This is a success\""
}

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_CYAN='\033[1;36m'
YELLOW='\033[1;33m'

gradient() {
	string=$1
	code=${2:-40}
	for (( i=0; i<${#string}; i++ )); do
		printf "\e[38;5;${code}m${string:$i:1}"
		if (( $i % 11 == 0 )); then
			code=$(($code+$i / 9))
		fi
	done
	printf "\n"
}

while getopts 'be:f:g:s:t:n:w:' option; do
	case "$option" in
		b)
			printf "\n\n"
			printf "   _____ __             __ \n"
			printf "  / ___// /_____ ______/ /_\n"
			printf "  \__ \/ __/ __ \`/ ___/ __/\n"
			printf " ___/ / /_/ /_/ / /  / /_  \n"
			printf "/____/\__/\__,_/_/   \__/  \n\n\n\n"

			printf "The ceremony has begun on this year of our Lord, two thousand twenty three.\n\n"

			exit 0
			;;
		e)
			ERROR="${OPTARG}"
			printf "${RED}${ERROR}${NC}\n"
			exit 1
			;;
		f)
			GRADIENT_START=${OPTARG}
			printf "\n\n\n\n"
			gradient "    _   ____________  ____  _____" "${GRADIENT_START}"
			gradient "   / | / / ____/ __ \/ __ \/ ___/" "${GRADIENT_START}"
			gradient "  /  |/ / __/ / /_/ / / / /\__ \ " "${GRADIENT_START}"
			gradient " / /|  / /___/ _, _/ /_/ /___/ / " "${GRADIENT_START}"
			gradient "/_/ |_/_____/_/ |_/_____//____/  " "${GRADIENT_START}"
			printf "\n\n\n${NC}"

			exit 0
			;;
		g)
			TEXT="${OPTARG}"
			gradient "${TEXT}"

			exit 0
			;;
		h)
			usage
			exit 0
			;;
		n)
			NOTE="${OPTARG}"
			printf "${LIGHT_CYAN}${NOTE}${NC}\n"
			exit 0
			;;
		s)
			SUCCESS="${OPTARG}"
			printf "${GREEN}${SUCCESS}${NC}\n"
			exit 0
			;;
		t)
			TITLE="${OPTARG}"
			STRING_LENGTH=${#TITLE}
			LINE_LENGTH=$(tput cols)
			CHARACTERS_TO_PRINT=$(($LINE_LENGTH - $STRING_LENGTH - 3))

			printf "\n${TITLE} : "
			printf -- "*%.0s" $(seq 1 $CHARACTERS_TO_PRINT)
			printf "\n"
			exit 0
			;;
		w)
			SUCCESS="${OPTARG}"
			printf "${YELLOW}${SUCCESS}${NC}\n"
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done

