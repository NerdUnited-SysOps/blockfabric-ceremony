package summary

import (
	bridge_common "bridge-deployer/common"
	bridge_logger "bridge-deployer/logging"

	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

var log = bridge_logger.GetInstance()

func BridgeContract(rpcUrl string, addressString string) {
	address := common.HexToAddress(addressString)
	ethClient, err := ethclient.Dial(rpcUrl)

	balance, err := ethClient.BalanceAt(context.Background(), address, nil)
	if err != nil {
		log.Printf("There was an error checking bridge balance for contract: %s", address.Hex())
	}
	approver, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(0))
	if err != nil {
		log.Println("error getting approver from storage")
		panic(err)
	}
	notary, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(1))
	if err != nil {
		log.Println("error getting notary from storage")
		panic(err)
	}
	feeReceiver, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(2))
	if err != nil {
		log.Println("error getting feeReceiver from storage")
		panic(err)
	}
	fee, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(6))
	if err != nil {
		log.Println("error getting fee from storage")
		panic(err)
	}
	log.Println("----------------------------------------")
	log.Printf("Bridge contract:        " + address.Hex())
	log.Println("----------------------------------------")
	log.Println("Balance:               " + balance.String())
	log.Println("----------------------------------------")
	log.Println("Approver:              " + *approver)
	log.Println("Notary:                " + *notary)
	log.Println("FeeReceiver:           " + *feeReceiver)
	log.Println("Fee:                   " + *fee)
	log.Println()
}

func BridgeMinterContract(rpcUrl string, addressString string) {
	address := common.HexToAddress(addressString)
	ethClient, err := ethclient.Dial(rpcUrl)

	balance, err := ethClient.BalanceAt(context.Background(), address, nil)
	if err != nil {
		log.Printf("There was an error checking bridge balance for contract: %s", address.Hex())
	}

	notary, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(0))
	if err != nil {
		log.Println("error getting notary from storage")
		panic(err)
	}
	approver, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(1))
	if err != nil {
		log.Println("error getting approver from storage")
		panic(err)
	}
	tokenAddress, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(2))
	if err != nil {
		log.Println("error getting tokenAddress from storage")
		panic(err)
	}

	log.Println("----------------------------------------")
	log.Println("BridgeMinter contract: " + address.Hex())
	log.Println("----------------------------------------")
	log.Println("Balance:               " + balance.String())
	log.Println("----------------------------------------")
	log.Println("Notary:                " + *notary)
	log.Println("Approver:              " + *approver)
	log.Println("Token Address:         " + *tokenAddress)
}

func TokenContract(rpcUrl string, addressString string) {
	address := common.HexToAddress(addressString)

	log.Printf("rpcurl %s", rpcUrl)
	ethClient, err := ethclient.Dial(rpcUrl)
	if err != nil {
		log.Printf("Failed to create ethClient")
	}

	balance, err := ethClient.BalanceAt(context.Background(), address, nil)
	if err != nil {
		log.Printf("There was an error checking token balance for contract: %s", address.Hex())
	}
	owner, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(0))
	if err != nil {
		log.Println("error getting owner from storage")
		panic(err)
	}
	issuerAndDecimals, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(2))
	if err != nil {
		log.Println("error getting issuer/decimals from storage")
		panic(err)
	}

	issuer := (*issuerAndDecimals)[24:len(*issuerAndDecimals)]
	decimals := (*issuerAndDecimals)[0:24]

	maxSupply, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(4))
	if err != nil {
		log.Println("error getting maxSupply from storage")
		panic(err)
	}

	name, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(7))
	if err != nil {
		log.Println("error getting name from storage")
		panic(err)
	}
	symbol, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(8))
	if err != nil {
		log.Println("error getting symbol from storage")
		panic(err)
	}
	log.Println("----------------------------------------")
	log.Printf("Token contract:         " + address.Hex())
	log.Println("----------------------------------------")
	log.Println("Balance:               " + balance.String())
	log.Println("----------------------------------------")
	log.Println("Name:                  " + *name)
	log.Println("Symbol:                " + *symbol)
	log.Println("Owner:                 " + *owner)
	log.Println("Issuer:                " + issuer)
	log.Println("Decimals:              " + decimals)
	log.Println("Max Supply:            " + *maxSupply)
	log.Println()
}
