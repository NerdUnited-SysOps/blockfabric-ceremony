package main

import (
	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"
	bridge_summary "bridge-deployer/summary"
	bridge_validate "bridge-deployer/validate"
	"errors"
	"fmt"

	"context"
	"math/big"
	"os"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	bridge "github.com/nerdcoresdk/neptune/pkg/contracts"
)

var log = bridge_logger.GetInstance()

func main() {

	log.Println("Deploying L1 ERC20 Token")

	ethRpcUrl := os.Args[1]
	deployerPrivateKey := os.Args[2]
	tokenName := os.Args[3]
	tokenSymbol := os.Args[4]
	tokenDecimalsArg := os.Args[5]
	tokenMaxSupplyArg := os.Args[6]
	tokenOwnerAddress := os.Args[7]

	config, err := bridge_common.InitConfig(ethRpcUrl, deployerPrivateKey, bridge_common.London)
	if err != nil {
		panic(err)
	}
	deployerAddress, err := bridge_common.GetAddressFromPrivateKey(deployerPrivateKey)
	if err != nil {
		panic(err)
	}
	tokenIssuerAddress := bridge_common.GetDeterministicAddress(deployerAddress, config.Auth.Auth.Nonce.Uint64()+1)
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
	config.Token = bridge_config.GetToken(tokenOwner, tokenIssuerAddress, tokenName, tokenSymbol, int(tokenDecimals), *maxSupply)
	config.Print()

	instance, err := deploy(config)
	if err != nil {
		log.Println("There was an error deploying the token contract")
		panic(err)
	}
	config.Token.Instance = instance

	// write the bridge address to a filefile
	f, err := os.Create("token_contract_address")
	if err != nil {
		panic(err)
	}
	defer f.Close()
	n2, err := f.Write([]byte(config.Token.Address.Hex()))
	if err != nil {
		panic(err)
	}
	fmt.Printf("wrote %d bytes\n", n2)
	f.Sync()

	bridge_summary.TokenContract(config)
	bridge_validate.TokenContract(config)

	log.Println("Token contract (token.sol) deployment complete")
}

func deploy(config *bridge_config.Config) (*bridge.Token, error) {

	// Deploy Token
	deployedTokenContractAddress, txn, token, err := bridge.DeployToken(config.Auth.Auth, config.EthClient, config.Token.Name, config.Token.Symbol, uint8(config.Token.Decimals), config.Token.Owner, config.Token.Issuer, &config.Token.MaxSupply)
	config.Token.Address = deployedTokenContractAddress
	if err != nil {
		if txn != nil {
			log.Println("txn hash: ", txn.Hash())
			log.Println("txn cost: ", txn.Cost())
		}
		panic(err)
	}
	receipt, err := bind.WaitMined(context.Background(), config.EthClient, txn)
	if receipt.Status == types.ReceiptStatusFailed {
		return nil, errors.New("token/deploy(): DeployToken failed")
	}

	return token, err
}
