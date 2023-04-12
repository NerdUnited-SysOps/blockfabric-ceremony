package main

import (
	bridge_summary "bridge-deployer/summary"
	bridge_validate "bridge-deployer/validate"
	"os"
)

func main() {
	rpcUrl := os.Args[1]
	bridgeMinterAddress := os.Args[2]
	tokenAddress := os.Args[3]

	bridge_summary.BridgeMinterContract(rpcUrl, bridgeMinterAddress)
	bridge_validate.BridgeMinterContract(rpcUrl, bridgeMinterAddress, tokenAddress)
}
