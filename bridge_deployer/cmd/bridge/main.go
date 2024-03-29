package main

import (
	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"
	"context"
	"errors"
	"fmt"

	"math/big"
	"os"
	"strconv"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	bridge "github.com/nerdcoresdk/neptune/pkg/contracts"
)

var log = bridge_logger.GetInstance()

type Bridge struct {
	Owner       common.Address
	Approver    common.Address
	Notary      common.Address
	FeeReceiver common.Address
	Fee         big.Int
}

func main() {

	log.Println("Bridge contract (bridge.sol) deployment initiated.")

	log.Println("Deploying L2 bridge")

	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	approverAddress := os.Args[3]
	notaryAddress := os.Args[4]
	feeReceiverAddress := os.Args[5]
	feeArg := os.Args[6]
	chainArg := os.Args[7]
	chainResult, err := strconv.ParseInt(chainArg, 10, 32)

	config, err := bridge_common.InitConfig(ethRpcUrl, deployerPrivateKey, bridge_common.Legacy)
	if err != nil {
		panic(err)
	}
	config.ChainId = *big.NewInt(chainResult)

	// Setup params
	bridgeApprover := common.HexToAddress(approverAddress)
	bridgeNotary := common.HexToAddress(notaryAddress)
	bridgeFeeReceiver := common.HexToAddress(feeReceiverAddress)
	feeResult, err := strconv.ParseInt(feeArg, 10, 64)
	if err != nil {
		panic(err)
	}
	fee := big.NewInt(feeResult)

	config.Bridge = bridge_config.GetBridge(common.HexToAddress("0"), bridgeApprover, bridgeNotary, bridgeFeeReceiver, *fee)
	config.Print()
	instance, err := deploy(config)
	if err != nil {
		log.Println("There was an error deploying the bridge contract")
		panic(err)
	}
	config.Bridge.Instance = instance

	// write the bridge address to a filefile
	f, err := os.Create("bridge_address")
	if err != nil {
		panic(err)
	}
	defer f.Close()
	n2, err := f.Write([]byte(config.Bridge.Address.Hex()))
	if err != nil {
		panic(err)
	}
	fmt.Printf("wrote %d bytes\n", n2)
	f.Sync()

	log.Println("Bridge contract (bridge.sol) deployment complete")
}

func deploy(config *bridge_config.Config) (*bridge.Bridge, error) {

	// Deploy Bridge
	address, txn, bridge, err := bridge.DeployBridge(config.Auth.Auth, config.EthClient, config.Bridge.Approver, config.Bridge.Notary, config.Bridge.FeeReceiver, &config.Bridge.Fee, &config.ChainId)
	config.Bridge.Address = address
	if err != nil {
		if txn != nil {
			log.Println("txn hash: ", txn.Hash())
			log.Println("txn cost: ", txn.Cost())
		}
		panic(err)
	}
	receipt, err := bind.WaitMined(context.Background(), config.EthClient, txn)
	if receipt.Status == types.ReceiptStatusFailed {
		return nil, errors.New("bridge/deploy(): DeployBridge failed")
	}

	return bridge, err
}
