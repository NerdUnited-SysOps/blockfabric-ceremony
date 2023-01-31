package main

import (
	bridge_common "bridge-deployer/common"
	"fmt"
	"log"
	"math/big"
	"os"
	"strconv"

	bridge "github.com/elevate-blockchain/neptune/pkg/contracts"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// If the file doesn't exist, create it or append to the file
	file, err := os.OpenFile("bridge.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	if err != nil {
		log.Fatal(err)
	}
	log.SetOutput(file)

	log.Println("Deploying L2 bridge")

	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	approverAddress := os.Args[3]
	notaryAddress := os.Args[4]
	feeReceiverAddress := os.Args[5]
	feeArg := os.Args[6]
	chainArg := os.Args[7]
	chainResult, err := strconv.ParseInt(chainArg, 10, 32)
	if err != nil {
		panic(err)
	}
	chainId := big.NewInt(chainResult)

	client, err := ethclient.Dial(ethRpcUrl)

	if err != nil {
		panic(err)
	}

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey, bridge_common.Legacy)

	// Setup params
	bridgeApprover := common.HexToAddress(approverAddress)
	bridgeNotary := common.HexToAddress(notaryAddress)
	bridgeFeeReceiver := common.HexToAddress(feeReceiverAddress)
	feeResult, err := strconv.ParseInt(feeArg, 10, 64)
	if err != nil {
		panic(err)
	}
	fee := big.NewInt(feeResult)

	// Deploy Bridge
	deployedBridgeContractAddress, txn, _, err := bridge.DeployBridge(auth, client, bridgeApprover, bridgeNotary, bridgeFeeReceiver, fee, chainId)
	if err != nil {
		if txn != nil {
			log.Println("txn hash: ", txn.Hash())
			log.Println("txn cost: ", txn.Cost())
		}
		panic(err)
	}
	log.Println("Txn hash: ", txn.Hash())
	log.Println(deployedBridgeContractAddress.Hex())
	fmt.Println(deployedBridgeContractAddress.Hex())
}
