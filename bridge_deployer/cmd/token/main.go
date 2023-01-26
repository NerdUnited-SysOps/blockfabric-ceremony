package main

import (
	bridge_common "bridge-deployer/common"
	"context"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"strings"

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
	tokenMaxSupplyArg := os.Args[6]
	tokenOwnerAddress := os.Args[7]

	deployerAddress, err := bridge_common.GetAddressFromPrivateKey(deployerPrivateKey)
	if (err != nil) {
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
	fmt.Println("bridge minter address=", tokenIssuer)

	// create auth and transaction package for deploying smart contract
	auth := bridge_common.GetAccountAuth(client, deployerPrivateKey, uint64(30000), *big.NewInt(1000000))

	// Setup params
	tokenOwner := common.HexToAddress(strings.TrimSpace(tokenOwnerAddress))

	maxSupplyResult, err := strconv.ParseInt(tokenMaxSupplyArg, 10, 32)
	if err != nil {
		panic(err)
	}
	maxSupply := big.NewInt(maxSupplyResult)
	tokenDecimalsResult, err := strconv.ParseInt(tokenDecimalsArg, 10, 32)
	if err != nil {
		panic(err)
	}
	tokenDecimals := uint8(tokenDecimalsResult)
	if err != nil {
		panic(err)
	}

	fmt.Println("tokenName=", tokenName)
	fmt.Println("tokenSymbol=", tokenSymbol)
	fmt.Println("tokenDecimals=", tokenDecimals)
	fmt.Println("tokenOwner=", tokenOwner)
	fmt.Println("tokenIssuer=", tokenIssuer)
	fmt.Println("maxSupply=", maxSupply)
	// Deploy Token
	deployedTokenContractAddress, _, _, err := bridge.DeployToken(auth, client, tokenName, tokenSymbol, tokenDecimals, tokenOwner, tokenIssuer, maxSupply)
	if err != nil {
		panic(err)
	}

	fmt.Println(deployedTokenContractAddress.Hex())
}
