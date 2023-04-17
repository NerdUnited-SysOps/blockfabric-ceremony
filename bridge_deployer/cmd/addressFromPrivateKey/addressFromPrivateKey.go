package main

import (
	"crypto/ecdsa"
	"errors"
	"fmt"
	"log"
	"os"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

func main() {
	address, err := GetAddressFromPrivateKeyStr(os.Args[1])
	if err != nil {
		log.Println("Failed to decrypt public address", err)
	}
	fmt.Println(address)
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
