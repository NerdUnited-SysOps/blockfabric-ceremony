package main

import (
	bridge_common "bridge-deployer/common"
	"context"
	"fmt"
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

	log.Println("Deploying L1 ERC20 Token")

	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	tokenName := os.Args[3]
	tokenSymbol := os.Args[4]
	tokenDecimalsArg := os.Args[5]
	tokenMaxSupplyArg := os.Args[6]
	tokenOwnerAddress := os.Args[7]

	deployerAddress, err := bridge_common.GetAddressFromPrivateKey(deployerPrivateKey)
	if err != nil {
		panic(err)
	}

	client, err := ethclient.Dial(ethRpcUrl)
	if err != nil {
		panic(err)
	}

	nonce, err := client.PendingNonceAt(context.Background(), deployerAddress)
	if err != nil {
		panic(err)
	}

	nonce = nonce + 1

	tokenIssuer := bridge_common.GetDeterministicAddress(deployerAddress, nonce)
	log.Println("bridge minter address=", tokenIssuer)

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey)

	// Setup params
	tokenOwner := common.HexToAddress(strings.TrimSpace(tokenOwnerAddress))

	maxSupply := big.NewInt(0)
	if _, ok := maxSupply.SetString(tokenMaxSupplyArg, 10); ok {
		log.Printf("number = %v\n", maxSupply)
	} else {
		log.Printf("error parsing line %#v\n", tokenMaxSupplyArg)
	}
	tokenDecimalsResult, err := strconv.ParseInt(tokenDecimalsArg, 10, 32)
	if err != nil {
		panic(err)
	}
	tokenDecimals := uint8(tokenDecimalsResult)
	if err != nil {
		panic(err)
	}

	log.Println("tokenName=", tokenName)
	log.Println("tokenSymbol=", tokenSymbol)
	log.Println("tokenDecimals=", tokenDecimals)
	log.Println("tokenOwner=", tokenOwner)
	log.Println("tokenIssuer=", tokenIssuer)
	log.Println("maxSupply=", maxSupply)

	// Deploy Token
	deployedTokenContractAddress, _, _, err := bridge.DeployToken(auth, client, tokenName, tokenSymbol, tokenDecimals, tokenOwner, tokenIssuer, maxSupply)
	if err != nil {
		panic(err)
	}

	fmt.Println(deployedTokenContractAddress.Hex())
}
