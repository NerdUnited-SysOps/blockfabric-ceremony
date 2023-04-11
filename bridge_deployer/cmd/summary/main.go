package main

import (
	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"
	summary "bridge-deployer/summary"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
)

var log = bridge_logger.GetInstance()

func main() {
	log.Println("Summary")

	config, err := bridge_common.InitConfig("https://rpc.nerdcore.testnet.blockfabric.net:8669", "1111111111111111111111111111111111111111111111111111111111111111", bridge_common.Legacy)
	if err != nil {
		log.Printf("Error reading config: %s", err)
	}
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

	tokenAddressStr := os.Args[1]
	tokenAddress := common.Address{}
	if len(tokenAddressStr) != 0 {
		tokenAddress = common.HexToAddress(strings.TrimSpace(tokenAddressStr))
	}
	config.Token = bridge_config.GetToken(tokenAddress, common.HexToAddress("0x0"), "name", "SYM", 8, *big.NewInt(3000))
	config.Token.Address = tokenAddress

	// Print summary
	summary.BridgeContract(config.EthClient, bridgeAddress)
	summary.BridgeMinterContract(config.EthClient, bridgeMinterAddress)
	summary.TokenContract(config)
}
