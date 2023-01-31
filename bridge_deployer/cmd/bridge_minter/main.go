package main

import (
	bridge_common "bridge-deployer/common"
	"log"
	"math/big"
	"os"
	"strconv"
	"strings"

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
	tokenAddress := os.Args[5]
	chainArg := os.Args[6]

	client, err := ethclient.Dial(ethRpcUrl)

	if err != nil {
		panic(err)
	}

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey)

	// Setup params
	bridgeApprover := common.HexToAddress(strings.TrimSpace(approverAddress))
	bridgeNotary := common.HexToAddress(strings.TrimSpace(notaryAddress))
	tokenContractAddress := common.HexToAddress(strings.TrimSpace(tokenAddress))
	chainResult, err := strconv.ParseInt(chainArg, 10, 32)
	if err != nil {
		panic(err)
	}
	chainId := big.NewInt(chainResult)

	log.Println("bridgeApprover=", bridgeApprover)
	log.Println("bridgeNotary=", bridgeNotary)
	log.Println("tokenContractAddress=", tokenContractAddress)
	log.Println("chainId=", chainId)

	// Deploy Bridge Minter
	deployedBridgeMinterContractAddress, _, _, err := bridge.DeployBridgeMinter(auth, client, bridgeApprover, bridgeNotary, tokenContractAddress, chainId)
	if err != nil {
		panic(err)
	}

	log.Println(deployedBridgeMinterContractAddress.Hex())
}
