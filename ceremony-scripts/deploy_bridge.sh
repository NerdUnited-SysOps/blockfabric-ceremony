#!/usr/bin/zsh

set -e

ENV_FILE=./.env
SCRIPTS_DIR=$(realpath ./ceremony-scripts)

usage() {
	echo "This script is a helper for deploying bridge smart contracts"
	echo "Options"
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

export GOPRIVATE=github.com/elevate-blockchain/*

cd ../bridge-deployer

go get github.com/elevate-blockchain/neptune/pkg/contracts

go run ../bridge_deployer/cmd/main.go 
    http://127.0.0.1:7545 
    502c2cac7df7a73197b06e70b5ae1e0f02dfc9edd32aabe8c3c59e58aa4ff52f 
    0x306bf6Ea79E4B45713251c9d5e989C987feB8DAb 
    0x3A9932f3D23e7991EBC93178e4d4c75C5284d637 
    0xA3cA95b98225013b5Ef2804330F40CAA04a4327F 
    0xf06360ddAE137941723806131F69f68196b16704 
    0x6592c955f86C0539415438Fcd52cF5091FeBB285 
    "JBToken" 
    "JBT"