package main

import (
	bridge_common "bridge-deployer/common"
	"fmt"
	"math/big"
	"os"

	bridge "github.com/elevate-blockchain/neptune/pkg/contracts"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	tokenName := os.Args[3]
	tokenSymbol := os.Args[4]
	tokenOwnerAddress := os.Args[5]
	tokenIssuerAddress := os.Args[6]
	client, err := ethclient.Dial(ethRpcUrl)

	if err != nil {
		panic(err)
	}

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey)

	// Setup params
	tokenOwner := common.HexToAddress(tokenOwnerAddress)
	tokenIssuer := common.HexToAddress(tokenIssuerAddress)
	fee := big.NewInt(10)

	if err != nil {
		panic(err)
	}

	// Deploy Token
	deployedTokenContractAddress, _, _, err := bridge.DeployToken(auth, client, tokenName, tokenSymbol, 18, tokenOwner, tokenIssuer, fee)
	if err != nil {
		panic(err)
	}

	fmt.Println(deployedTokenContractAddress.Hex())
}