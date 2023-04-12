package main

import (
	bridge_summary "bridge-deployer/summary"
	bridge_validate "bridge-deployer/validate"
	"os"
)

func main() {
	rpcUrl := os.Args[1]
	tokenAddress := os.Args[2]

	bridge_summary.TokenContract(rpcUrl, tokenAddress)
	bridge_validate.TokenContract(rpcUrl, tokenAddress)
}
