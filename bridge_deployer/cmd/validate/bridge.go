package main

import (
	bridge_summary "bridge-deployer/summary"
	bridge_validate "bridge-deployer/validate"
	"os"
)

func main() {
	rpcUrl := os.Args[1]
	bridgeAddress := os.Args[2]

	bridge_summary.BridgeContract(rpcUrl, bridgeAddress)
	bridge_validate.BridgeContract(rpcUrl, bridgeAddress)
}
