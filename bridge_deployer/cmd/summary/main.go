package main

import (
	bridge_common "bridge-deployer/common"
	bridge_logger "bridge-deployer/logging"
	summary "bridge-deployer/summary"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
)

var log = bridge_logger.GetInstance()

func main() {
	log.Println("Summary")

	if err != nil {
		log.Printf("Error reading config: %s", err)
	}

	config := bridge_common.InitConfig(auth, client, bridge)

	// Get lockupAddress from command call args
	bridgeAddressStr := os.Args[1]
	bridgeAddress := common.Address{}
	if len(bridgeAddressStr) != 0 {
		bridgeAddress = common.HexToAddress(strings.TrimSpace(bridgeAddressStr))
	}

	// Get distributionAddress from command call args
	bridgeMinterAddress := common.Address{}
	bridgeMinterAddressStr := os.Args[2]
	if len(bridgeMinterAddressStr) != 0 {
		bridgeMinterAddress = common.HexToAddress(strings.TrimSpace(bridgeMinterAddressStr))
	}

	tokenAddressStr := os.Args[3]
	tokenAddress := common.Address{}
	if len(tokenAddressStr) != 0 {
		tokenAddress = common.HexToAddress(strings.TrimSpace(tokenAddressStr))
	}

	// Print summary
	summary.BridgeContract(config.EthClient, bridgeAddress)
	summary.BridgeMinterContract(config.EthClient, bridgeMinterAddress)
	//summary.TokenContract(config.EthClient, tokenAddress)
}
