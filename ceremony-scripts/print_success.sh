#!/usr/bin/env bash

SUCCESS=${1:?Error, no this function requires a string input}

BASE_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source .common.sh

printf "${GREEN}${SUCCESS}${NC}\n"

