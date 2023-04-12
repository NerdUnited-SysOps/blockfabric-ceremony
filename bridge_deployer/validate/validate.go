package validate

import (
	"errors"
	"math/big"
	"strings"

	bridge_common "bridge-deployer/common"
	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

var log = bridge_logger.GetInstance()

const (
	ApproverPath   string = "../volumes/volume3/approver/"
	NotaryPath            = "../volumes/volume2/notary/"
	TokenOwnerPath        = "../volumes/volume2/token_owner/"
)

func getWalletFromKeystorePath(path string) (*bridge_config.Wallet, error) {

	wallet, err := bridge_common.DecryptKeystore(path+"keystore", path+"password")
	if wallet == nil {
		return nil, errors.New("validate/validateKeystoreByPath(): DecryptKeystore() failed, path:" + path + err.Error())
	}

	return wallet, err
}

func validateAddressInStorage(rpcUrl string, address common.Address, contractAddress common.Address, storageIndex int) bool {
	ethClient, err := ethclient.Dial(rpcUrl)
	addr := strings.ToLower(strings.TrimPrefix(address.Hex(), "0x"))

	storage, err := bridge_common.GetStorageAt(contractAddress, ethClient, big.NewInt(int64(storageIndex)))
	if err != nil {
		log.Printf("error getting index [%v] from storage\n", storageIndex)
	}

	addr2 := strings.ToLower(strings.TrimPrefix(*storage, "000000000000000000000000"))

	return addr == addr2
}

func validateBridgeKeys(rpcUrl string, bridgeAddress string) (bool, error) {
	approverWallet, err := getWalletFromKeystorePath(ApproverPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(rpcUrl, approverWallet.Address, common.HexToAddress(bridgeAddress), 0) {
		log.Println("Bridge approver keystore address matches on-chain bridge storage\t✓")
	} else {
		log.Println("ERROR: Bridge approver keystore address does not match on-chain bridge storage")
	}
	notaryWallet, err := getWalletFromKeystorePath(NotaryPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(rpcUrl, notaryWallet.Address, common.HexToAddress(bridgeAddress), 1) {
		log.Println("Bridge notary keystore address matches on-chain bridge storage\t✓")
	} else {
		log.Println("ERROR: Bridge notary keystore address does not match on-chain bridge storage")
	}
	log.Println("Validation complete")

	return true, nil
}

func BridgeContract(rpcUrl string, bridgeAddress string) {
	log.Println("Validation starting")
	log.Println("Validating bridge keys")
	_, err := validateBridgeKeys(rpcUrl, bridgeAddress)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Validation complete: success")
}

func TokenContract(rpcUrl string, tokenAddress string) {
	log.Println("Validation starting")
	log.Println("Validating token contract")
	ownerWallet, err := getWalletFromKeystorePath(TokenOwnerPath)
	if err != nil {
		log.Fatal(err)
	}

	if validateAddressInStorage(rpcUrl, ownerWallet.Address, common.HexToAddress(tokenAddress), 0) {
		log.Println("Token owner keystore address matches on-chain token storage\t✓")
	} else {
		log.Println("ERROR: Token owner keystore address does not match on-chain token storage")
	}
	log.Println("Validation complete")
}

func BridgeMinterContract(rpcUrl string, bridgeMinterAddress string, tokenAddress string) {

	notaryWallet, err := getWalletFromKeystorePath(NotaryPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(rpcUrl, notaryWallet.Address, common.HexToAddress(bridgeMinterAddress), 0) {
		log.Println("Bridge minter notary keystore address matches on-chain bridge minter storage\t\t✓")
	} else {
		log.Println("ERROR: Bridge minter notary keystore address does not match on-chain bridge minter storage")
	}

	approverWallet, err := getWalletFromKeystorePath(ApproverPath)
	if err != nil {
		log.Fatal(err)
	}
	if validateAddressInStorage(rpcUrl, approverWallet.Address, common.HexToAddress(bridgeMinterAddress), 1) {
		log.Println("Bridge minter approver keystore address matches on-chain bridge minter storage\t\t✓")
	} else {
		log.Println("ERROR: Bridge minter approver keystore address does not match on-chain bridge minter storage")
	}
	// validate token contract address
	tokenAddress = strings.ToLower(strings.TrimPrefix(tokenAddress, "0x"))

	ethClient, err := ethclient.Dial(rpcUrl)
	storage, err := bridge_common.GetStorageAt(common.HexToAddress(bridgeMinterAddress), ethClient, big.NewInt(int64(2)))
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
