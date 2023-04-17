package main

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"log"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	toAddress := os.Args[1]
	privateKey := os.Args[2]
	rpcUrl := os.Args[3]
	amount := os.Args[4]
	value := new(big.Int)
	value.SetString(amount, 10)
	sendCoins(rpcUrl, privateKey, common.HexToAddress(toAddress), value)
}

func sendCoins(rpcUrl string, senderPrivateKey string, toAddress common.Address, value *big.Int) (*types.Transaction, error) {
	ethClient, _ := ethclient.Dial(rpcUrl)

	gasLimit := uint64(21000)
	var nonce uint64
	var err error

	privateKey, err := crypto.HexToECDSA(senderPrivateKey)
	if err != nil {
		log.Fatal("Failed to get privateKey", err)
		panic(err)
	}
	fromAddress, _ := GetAddressFromPrivateKeyStr(senderPrivateKey)

	nonce, err = ethClient.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		panic(err)
	}

	gasPrice, err := ethClient.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	var data []byte

	tx := types.NewTransaction(nonce, toAddress, value, gasLimit, gasPrice, data)

	chainID, err := ethClient.NetworkID(context.Background())
	if err != nil {
		log.Fatal("Failed to get chain id", err)
		panic(err)
	}

	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
	if err != nil {
		log.Fatal("Failed to sign transaction", err)
		panic(err)
	}

	log.Println("Sending", value, "coins from", fromAddress, "to", toAddress)
	err = ethClient.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatal("Failed to send transaction", err)
		panic(err)
	}
	log.Println("Executed transaction", signedTx.Hash())

	return signedTx, err
}

func GetAddressFromPrivateKeyStr(privateKeyStr string) (common.Address, error) {

	privateKey, err := crypto.HexToECDSA(privateKeyStr)
	if err != nil {
		return common.HexToAddress("0"), err
	}

	publicKeyECDSA, ok := privateKey.Public().(*ecdsa.PublicKey)
	if !ok {
		return common.HexToAddress("0"), errors.New("Private to public key conversion failed")
	}

	return crypto.PubkeyToAddress(*publicKeyECDSA), err
}
