#!/bin/bash

TITLE=${1?:Error, need a string to use the title}
STRING_LENGTH=${#TITLE}
LINE_LENGTH=$(tput cols)
CHARACTERS_TO_PRINT=$(($LINE_LENGTH - $STRING_LENGTH - 3))

printf "\n${TITLE} : "
printf -- "*%.0s" $(seq 1 $CHARACTERS_TO_PRINT)
printf "\n"
