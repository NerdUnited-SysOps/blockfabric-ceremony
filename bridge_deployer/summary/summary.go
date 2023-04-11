package summary

import (
	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"

	"context"
	"fmt"
	"math/big"
	"strconv"
	"time"
)

var log = bridge_logger.GetInstance()

func BridgeContract(config *bridge_config.Config) {
	address := config.Bridge.Address
	ethClient := config.EthClient

	log.Println("----------------------------------------")
	log.Printf("Bridge contract: " + address.Hex())
	log.Println("----------------------------------------")

	balance, err := ethClient.BalanceAt(context.Background(), address, nil)
	if err != nil {
		log.Printf("There was an error checking lockup balance for contract: %s", address.Hex())
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
	log.Println("Balance:         " + balance.String())
	log.Println("----------------------------------------")
	log.Println("Approver:        " + *approver)
	log.Println("Notary:          " + *notary)
	log.Println("FeeReceiver:     " + *feeReceiver)
	log.Println("Fee:             " + *fee)
	log.Println()
}

func BridgeMinterContract(config *bridge_config.Config) {
	ethClient := config.EthClient
	address := config.Bridge.Address

	log.Println("----------------------------------------")
	log.Println("BridgeMinter contract: " + address.Hex())
	log.Println("----------------------------------------")
	balance, err := ethClient.BalanceAt(context.Background(), address, nil)
	if err != nil {
		log.Println("There was an error checking BridgeMinter balance for contract: " + address.Hex())
	}

	owner, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(0))
	if err != nil {
		log.Println("error getting owner from storage")
		panic(err)
	}
	bridge, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(2))
	if err != nil {
		log.Println("error getting bridge from storage")
		panic(err)
	}
	dailyLimit, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(4))
	if err != nil {
		log.Println("error getting dailyLimit from storage")
		panic(err)
	}
	lastBridge, err := bridge_common.GetStorageAt(address, ethClient, big.NewInt(5))
	if err != nil {
		log.Println("error getting lastBridge from storage")
		panic(err)
	}
	lastDistroInt, err := strconv.ParseInt(*lastBridge, 16, 64)
	if err != nil {
		log.Println("error converting lastBridge to int")
		panic(err)
	}
	intUnix, err := strconv.ParseInt(fmt.Sprint(lastDistroInt), 10, 64)
	if err != nil {
		log.Fatal(err)
	}
	lastDistroTime := time.Unix(intUnix, 0)

	log.Println("Balance:             " + balance.String())
	log.Println("----------------------------------------")
	log.Println("Owner:               " + *owner)
	log.Println("Issuer:              " + *bridge + " - Bridge contract")
	log.Println("DailyLimit:          " + *dailyLimit)
	log.Println("LastBridge:    " + fmt.Sprint(intUnix) + " ..." + lastDistroTime.String())
}
