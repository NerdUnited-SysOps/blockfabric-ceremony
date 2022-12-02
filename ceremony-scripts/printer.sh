#!/usr/bin/env bash

usage() {
  echo "This script is a helper for printing text"
  echo "Only one argument will be respected"
  echo "Usage: $0 (options) ..."
  echo "  -e : Error message"
  echo "  -s : Success message"
  echo "  -t : Title message"
  echo "  -n : Note message"
  echo "  -h : Help"
  echo ""
  echo "Example: printer.sh -t \"This is a title\""
  echo "Example: printer.sh -e \"This is an error\""
  echo "Example: printer.sh -s \"This is a success\""
}

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_CYAN='\033[1;36m'

while getopts 'e:s:t:n:' option; do
	case "$option" in
		s)
			SUCCESS="${OPTARG}"
			printf "${GREEN}${SUCCESS}${NC}\n"
			exit 0
			;;
		e)
			ERROR="${OPTARG}"
			printf "${RED}${ERROR}${NC}\n" >&2
			exit 1
			;;
		n)
			NOTE="${OPTARG}"
			printf "${LIGHT_CYAN}${NOTE}${NC}\n" >&2
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
		?)

			usage
			exit 1
			;;
	esac
done

shift $((OPTIND-1))
