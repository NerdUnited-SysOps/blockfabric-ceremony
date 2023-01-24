package main

import (
	bridge_common "bridge-deployer/common"
	"fmt"
	"math/big"
	"os"
	"strconv"

	bridge "github.com/elevate-blockchain/neptune/pkg/contracts"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
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
	bridgeApprover := common.HexToAddress(approverAddress)
	bridgeNotary := common.HexToAddress(notaryAddress)
	tokenContractAddress := common.HexToAddress(tokenAddress)
	chainResult, err := strconv.ParseInt(chainArg, 10, 32)
	if err != nil {
		panic(err)
	}
	chainId := big.NewInt(chainResult)

	// Deploy Bridge Minter
	deployedBridgeMinterContractAddress, _, _, err := bridge.DeployBridgeMinter(auth, client, bridgeApprover, bridgeNotary, tokenContractAddress, chainId)
	if err != nil {
		panic(err)
	}

	fmt.Println(deployedBridgeMinterContractAddress.Hex())
}