package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"

	bridge "github.com/elevate-blockchain/neptune/pkg/contracts"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func getAccountAuth(client *ethclient.Client, accountAddress string) *bind.TransactOpts {

	privateKey, err := crypto.HexToECDSA(accountAddress)
	if err != nil {
		panic(err)
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		panic("invalid key")
	}

	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)

	//fetch the last use nonce of account
	nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		panic(err)
	}
	fmt.Println("nonce=", nonce)
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		panic(err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		panic(err)
	}
	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = big.NewInt(0)      // in wei
	auth.GasLimit = uint64(3000000) // in units
	auth.GasPrice = big.NewInt(1000000)

	return auth
}

func main() {
	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	ownerAddress := os.Args[3]
	approverAddress := os.Args[4]
	notaryAddress := os.Args[5]
	feeReceiverAddress := os.Args[6]
	tokenOwnerAddress := os.Args[7]
	tokenName := os.Args[8] // "JBToken"
	tokenSymbol := os.Args[9] // "JBT"
	client, err := ethclient.Dial(ethRpcUrl) // "http://127.0.0.1:7545"

	if err != nil {
		panic(err)
	}

	// create auth and transaction package for deploying smart contract
	auth := getAccountAuth(client, deployerPrivateKey) // "502c2cac7df7a73197b06e70b5ae1e0f02dfc9edd32aabe8c3c59e58aa4ff52f"

	// Setup params
	bridgeOwner := common.HexToAddress(ownerAddress) // "0x306bf6Ea79E4B45713251c9d5e989C987feB8DAb"
	bridgeApprover := common.HexToAddress(approverAddress) // "0x3A9932f3D23e7991EBC93178e4d4c75C5284d637"
	bridgeNotary := common.HexToAddress(notaryAddress) // "0xA3cA95b98225013b5Ef2804330F40CAA04a4327F"
	bridgeFeeReceiver := common.HexToAddress(feeReceiverAddress) // "0xf06360ddAE137941723806131F69f68196b16704"
	// TODO Waiting on answer for what this wallet is
	tokenOwner := common.HexToAddress(tokenOwnerAddress) // "0x6592c955f86C0539415438Fcd52cF5091FeBB285"
	fee := big.NewInt(10)

	// Deploy Bridge
	deployedBridgeContractAddress, _, _, err := bridge.DeployBridge(auth, client, bridgeOwner, bridgeApprover, bridgeNotary, bridgeFeeReceiver, fee)
	if err != nil {
		panic(err)
	}

	// Deploy Token
	tokenContractAddress, _, _, err := bridge.DeployToken(auth, client, tokenName, tokenSymbol, 18, tokenOwner, deployedBridgeContractAddress, fee)
	if err != nil {
		panic(err)
	}

	// Deploy Bridge Minter
	deployedBridgeMinterContractAddress, _, _, err := bridge.DeployBridgeMinter(auth, client, bridgeOwner, bridgeApprover, bridgeNotary, tokenContractAddress)
	if err != nil {
		panic(err)
	}

	fmt.Println(deployedBridgeContractAddress.Hex())
	fmt.Println(tokenContractAddress.Hex())
	fmt.Println(deployedBridgeMinterContractAddress.Hex())
}