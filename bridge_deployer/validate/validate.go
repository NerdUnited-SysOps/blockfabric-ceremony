package validate

import (
	"errors"
	"math/big"
	"strings"

	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"

	"github.com/ethereum/go-ethereum/common"
)

var log = bridge_logger.GetInstance()

const (
	ApproverPath   string = "../volumes/volume3/approver/"
	NotaryPath            = "../volumes/volume2/notary/"
	TokenOwnerPath        = "../volumes/volume2/token_owner/"
)

func getWalletFromKeystorePath(config *bridge_config.Config, path string) (*bridge_config.Wallet, error) {

	wallet, err := bridge_common.DecryptKeystore(path+"keystore", path+"password")
	if wallet == nil {
		return nil, errors.New("validate/validateKeystoreByPath(): DecryptKeystore() failed, path:" + path + err.Error())
	}

	return wallet, err
}

func validateAddressInStorage(config *bridge_config.Config, address common.Address, contractAddress common.Address, storageIndex int) bool {
	addr := strings.ToLower(strings.TrimPrefix(address.Hex(), "0x"))

	storage, err := bridge_common.GetStorageAt(contractAddress, config.EthClient, big.NewInt(int64(storageIndex)))
	if err != nil {
		log.Printf("error getting index [%v] from storage\n", storageIndex)
	}

	addr2 := strings.ToLower(strings.TrimPrefix(*storage, "000000000000000000000000"))

	return addr == addr2
}

func validateBridgeKeys(config *bridge_config.Config) (bool, error) {
	approverWallet, err := getWalletFromKeystorePath(config, ApproverPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(config, approverWallet.Address, config.Bridge.Address, 0) {
		log.Println("Bridge approver keystore address matches on-chain bridge storage\t✓")
	} else {
		log.Println("ERROR: Bridge approver keystore address does not match on-chain bridge storage")
	}
	notaryWallet, err := getWalletFromKeystorePath(config, NotaryPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(config, notaryWallet.Address, config.Bridge.Address, 1) {
		log.Println("Bridge notary keystore address matches on-chain bridge storage\t✓")
	} else {
		log.Println("ERROR: Bridge notary keystore address does not match on-chain bridge storage")
	}
	log.Println("Validation complete")

	return true, nil
}

func BridgeContract(config *bridge_config.Config) {
	log.Println("Validation starting")
	log.Println("Validating bridge keys")
	_, err := validateBridgeKeys(config)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Validation complete: success")
}

func TokenContract(config *bridge_config.Config) {
	log.Println("Validation starting")
	log.Println("Validating token contract")
	ownerWallet, err := getWalletFromKeystorePath(config, TokenOwnerPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(config, ownerWallet.Address, config.Token.Address, 0) {
		log.Println("Token owner keystore address matches on-chain token storage\t✓")
	} else {
		log.Println("ERROR: Token owner keystore address does not match on-chain token storage")
	}
	log.Println("Validation complete")

	log.Println("Validation complete: success")
}

func BridgeMinterContract(config *bridge_config.Config) {

	notaryWallet, err := getWalletFromKeystorePath(config, NotaryPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(config, notaryWallet.Address, config.BridgeMinter.Address, 0) {
		log.Println("Bridge minter notary keystore address matches on-chain bridge minter storage\t✓")
	} else {
		log.Println("ERROR: Bridge minter notary keystore address does not match on-chain bridge minter storage")
	}

	approverWallet, err := getWalletFromKeystorePath(config, ApproverPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(config, approverWallet.Address, config.BridgeMinter.Address, 1) {
		log.Println("Bridge minter approver keystore address matches on-chain bridge minter storage\t✓")
	} else {
		log.Println("ERROR: Bridge minter approver keystore address does not match on-chain bridge minter storage")
	}
	// validate token contract address
	tokenAddress := strings.ToLower(strings.TrimPrefix(config.BridgeMinter.TokenAddress.Hex(), "0x"))

	storage, err := bridge_common.GetStorageAt(config.BridgeMinter.Address, config.EthClient, big.NewInt(int64(2)))
	if err != nil {
		log.Printf("error getting index [%v] from storage\n", 2)
	}
	tokenAddressStorage := strings.ToLower(strings.TrimPrefix(*storage, "000000000000000000000000"))

	if tokenAddress == tokenAddressStorage {
		log.Println("Bridge minter issuer (token contract) address matches on-chain bridge minter storage\t✓")
	} else {
		log.Println("ERROR: Bridge minter issuer (token contract) keystore address does not match on-chain bridge minter storage")
	}
	log.Println("Validation complete")
}
