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
	ApproverPath       string = "../volumes/volume5/approver/"
	NotaryPath                = "../volumes/volume5/notary/"
	MinterApproverPath        = "../volumes/volume5/bridge_minter_approver/"
	MinterNotaryPath          = "../volumes/volume5/bridge_minter_notary/"
)

func getWalletFromKeystorePath(config *bridge_config.Config, path string) (*bridge_config.Wallet, error) {

	wallet, err := bridge_common.DecryptKeystore(path+"keystore", path+"password")
	if wallet == nil {
		return nil, errors.New("validate/validateKeystoreByPath(): DecryptKeystore() failed, path:" + path + err.Error())
	}

	return wallet, err
}

func checkStorage(config *bridge_config.Config, address common.Address, contractAddress common.Address, storageIndex int) bool {
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
	if checkStorage(config, approverWallet.Address, config.Bridge.Address, 0) {
		log.Println("Bridge approver keystore address matches on-chain bridge storage\t✓")
	} else {
		log.Println("ERROR: Bridge approver keystore address does not match on-chain bridge storage")
	}
	notaryWallet, err := getWalletFromKeystorePath(config, NotaryPath)
	if err != nil {
		log.Fatal(err)
	}
	if checkStorage(config, notaryWallet.Address, config.Bridge.Address, 1) {
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

//func BridgeMinterContract(ethClient *ethclient.Client, address common.Address) {
//}
