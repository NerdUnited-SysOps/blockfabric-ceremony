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
	tokenName := os.Args[3]
	tokenSymbol := os.Args[4]
	tokenDecimalsArg := os.Args[5]
	feeArg := os.Args[6]
	tokenOwnerAddress := os.Args[7]
	tokenIssuerAddress := os.Args[8]

	client, err := ethclient.Dial(ethRpcUrl)

	if err != nil {
		panic(err)
	}

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey)

	// Setup params
	tokenOwner := common.HexToAddress(tokenOwnerAddress)
	tokenIssuer := common.HexToAddress(tokenIssuerAddress)
	feeResult, err := strconv.ParseInt(feeArg, 10, 32)
	if err != nil {
		panic(err)
	}
	fee := big.NewInt(feeResult)
	tokenDecimalsResult, err := strconv.ParseInt(tokenDecimalsArg, 10, 32)
	if err != nil {
		panic(err)
	}
	tokenDecimals := uint8(tokenDecimalsResult)

	if err != nil {
		panic(err)
	}

	// Deploy Token
	deployedTokenContractAddress, _, _, err := bridge.DeployToken(auth, client, tokenName, tokenSymbol, tokenDecimals, tokenOwner, tokenIssuer, fee)
	if err != nil {
		fmt.Printf("Err: %s", err.Error())
		panic(err)
	}

	fmt.Println(deployedTokenContractAddress.Hex())
}
