package common

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func GetAccountAuth(client *ethclient.Client, addressPrivateKey string) *bind.TransactOpts {
	privateKey, err := crypto.HexToECDSA(addressPrivateKey)
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

func GetAddressFromPrivateKey(addressPrivateKey string) (*common.Address, error) {
	privateKey, err := crypto.HexToECDSA(addressPrivateKey)
	if err != nil {
		return nil, errors.New("rror with private key")
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("Eror generating public key")
	}

	address := crypto.PubkeyToAddress(*publicKeyECDSA)
	return  &address, nil
}

func GetDeterministicAddress(address common.Address, nonce *uint64) (contractAddress common.Address) {
	return crypto.CreateAddress(common.HexToAddress(address.Hex()), *nonce)
}