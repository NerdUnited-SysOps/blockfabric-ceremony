package main

import (
	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"
	bridge_summary "bridge-deployer/summary"
	bridge_validate "bridge-deployer/validate"
	"context"
	"errors"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	bridge "github.com/nerdcoresdk/neptune/pkg/contracts"
)

var log = bridge_logger.GetInstance()

func main() {

	log.Println("Deploying L1 bridge")

	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	approverAddress := os.Args[3]
	notaryAddress := os.Args[4]
	tokenAddress := os.Args[5]
	chainArg := os.Args[6]

	// Setup params
	bridgeApprover := common.HexToAddress(strings.TrimSpace(approverAddress))
	bridgeNotary := common.HexToAddress(strings.TrimSpace(notaryAddress))
	tokenContractAddress := common.HexToAddress(strings.TrimSpace(tokenAddress))
	chainResult, err := strconv.ParseInt(chainArg, 10, 32)
	if err != nil {
		panic(err)
	}
	config, err := bridge_common.InitConfig(ethRpcUrl, deployerPrivateKey, bridge_common.London)
	if err != nil {
		panic(err)
	}
	config.ChainId = *big.NewInt(chainResult)

	config.BridgeMinter = bridge_config.GetBridgeMinter(common.HexToAddress("0"), bridgeApprover, bridgeNotary, tokenContractAddress)
	config.Print()

	instance, err := deploy(config, tokenContractAddress)
	if err != nil {
		log.Println("There was an error deploying the  L1 bridge minter contract")
		panic(err)
	}
	config.BridgeMinter.Instance = instance

	// write the bridge address to a filefile
	f, err := os.Create("bridge_minter_address")
	if err != nil {
		panic(err)
	}
	defer f.Close()
	n2, err := f.Write([]byte(config.BridgeMinter.Address.Hex()))
	if err != nil {
		panic(err)
	}
	fmt.Printf("wrote %d bytes\n", n2)
	f.Sync()

	bridge_summary.BridgeMinterContract(config)
	bridge_validate.BridgeMinterContract(config)
	log.Println("Bridge Minter contract (bridge_minter.sol) deployment complete")
}

func deploy(config *bridge_config.Config, tokenAddress common.Address) (*bridge.BridgeMinter, error) {

	// Deploy bridge_minter
	address, txn, bridgeMinter, err := bridge.DeployBridgeMinter(config.Auth.Auth, config.EthClient, config.BridgeMinter.Approver, config.BridgeMinter.Notary, tokenAddress, &config.ChainId)
	if err != nil {
		if txn != nil {
			log.Println("txn hash: ", txn.Hash())
			log.Println("txn cost: ", txn.Cost())
		}
		panic(err)
	}
	config.BridgeMinter.Address = address
	receipt, err := bind.WaitMined(context.Background(), config.EthClient, txn)
	if receipt.Status == types.ReceiptStatusFailed {
		return nil, errors.New("bridge/deploy(): DeployBridge failed")
	}

	return bridgeMinter, err
}
