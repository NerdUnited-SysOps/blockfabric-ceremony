package common

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"errors"
	"math/big"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	bridge_config "bridge-deployer/config"
	bridge_logger "bridge-deployer/logging"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/accounts/keystore"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

var log = bridge_logger.GetInstance()

func GetAccountAuth(client *ethclient.Client, addressPrivateKey string, signing int) *bridge_config.Auth {
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
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		panic(err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		panic(err)
	}

	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = big.NewInt(0) // in wei
	if signing == Legacy {
		gasPrice, err := client.SuggestGasPrice(context.Background())
		if err != nil {
			log.Fatal(err)
		}
		auth.GasLimit = uint64(12000000) // in units
		auth.GasPrice = gasPrice
	}

	return bridge_config.GetAuth(auth)
}

func GetAddressFromPrivateKey(addressPrivateKey string) (common.Address, error) {
	privateKey, err := crypto.HexToECDSA(addressPrivateKey)
	if err != nil {
		return common.Address{0}, errors.New("error with private key")
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return common.Address{0}, errors.New("error generating public key")
	}

	address := crypto.PubkeyToAddress(*publicKeyECDSA)
	return address, nil
}

func GetDeterministicAddress(address common.Address, nonce uint64) (contractAddress common.Address) {
	return crypto.CreateAddress(common.HexToAddress(address.Hex()), nonce)
}

func InitConfig(rpcUrl string, deployerPrivateKey string, signing int) (*bridge_config.Config, error) {

	client, err := ethclient.Dial(rpcUrl)
	if err != nil {
		return nil, errors.New("error dialing" + rpcUrl)
	}

	auth := GetAccountAuth(client, deployerPrivateKey, signing)

	cfg := bridge_config.GetConfig(
		"",
		"",
		*big.NewInt(0),
		deployerPrivateKey,
		auth,
		client,
		nil,
		nil,
		nil,
		nil,
	)

	return cfg, err
}
func GetAdminKey(path string) (string, error) {
	log.Println("Path: " + path)
	re := regexp.MustCompile("^[A-Fa-f0-9]{40}$")
	files, err := filteredSearchOfDirectoryTree(re, path)
	if err != nil {
		return "", err
	}
	adminKey, err := os.ReadFile(files[0])
	if err != nil {
		return "", err
	}

	return strings.TrimSuffix(string(adminKey), "\n"), err
}

// filteredSearchOfDirectoryTree Walks down a directory tree looking for
//
//	files that match the pattern: re. If a file is found add it to the
//	files list. Returns the list of files.
//
// Sourced from:
// https://gist.github.com/jlinoff/1c44eabd5a19c23a3e0755d6207891db#file-walker-go
func filteredSearchOfDirectoryTree(re *regexp.Regexp, dir string) ([]string, error) {

	files := []string{}

	walk := func(fn string, fi os.FileInfo, err error) error {

		if re.MatchString(filepath.Base(fn)) == false {
			return nil
		}

		if fi.IsDir() {
			log.Println(filepath.Base(fn) + string(os.PathSeparator))
		} else {
			files = append(files, fn)
		}
		return nil
	}
	err := filepath.Walk(dir, walk)

	return files, err
}

func getIssuerPrivateKey(awsInfo *bridge_config.AwsInfo) (*string, error) {
	sess, err := session.NewSession(&aws.Config{
		Region:      aws.String(awsInfo.AwsRegion),
		Credentials: credentials.NewSharedCredentials("", awsInfo.AwsProfile),
	})

	svc := secretsmanager.New(sess)

	passPhraseResult, err := svc.GetSecretValue(&secretsmanager.GetSecretValueInput{SecretId: &awsInfo.AwsSecretKeyName})
	if err != nil {
		log.Printf("there was an error getting the pass phrase from aws secrets manager: %s", err.Error())
		return nil, err
	}

	return passPhraseResult.SecretString, nil
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

func SendCoins(config *bridge_config.Config, toAddress common.Address, value *big.Int, wallet *bridge_config.Wallet) (*types.Transaction, error) {

	nonce, err := config.EthClient.PendingNonceAt(context.Background(), crypto.PubkeyToAddress(*wallet.Pub))

	if err != nil {
		log.Fatal(err)
	}
	tx := types.NewTransaction(nonce, toAddress, value, config.Auth.Auth.GasLimit, config.Auth.Auth.GasPrice, nil)
	chainID, err := config.EthClient.NetworkID(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), wallet.Priv)
	if err != nil {
		log.Fatal(err)
	}
	err = config.EthClient.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatal(err)
	}
	return signedTx, err
}

func GetBalance(client *ethclient.Client, account common.Address) (*big.Int, error) {

	balance, err := client.BalanceAt(context.Background(), account, nil)
	if err != nil {
		log.Fatal(err)
	}

	return balance, err
}

//func scGetter(instance *lockupV1.Lockup) (*big.Int, error) {
//	ret, err := instance.GetterFunc(nil)
//	if err != nil {
//		log.Fatal(err)
//	}
//
//	return ret, err
//}

/*
getStorageAt() - Get string values from smart contract storage by position

	address - Contract address
	client - ethClient
	position - Position in storage to read
*/
func GetStorageAt(address common.Address, client *ethclient.Client, position *big.Int) (*string, error) {
	blockNumber, err := client.BlockNumber(context.Background())
	if err != nil {
		return nil, err
	}
	blockNumberInt := new(big.Int).SetUint64(blockNumber)
	positionHash := common.BigToHash(position)
	storageBytes, err := client.StorageAt(context.Background(), address, positionHash, blockNumberInt)
	if err != nil {
		return nil, err
	}
	storageStr := hex.EncodeToString(storageBytes)
	return &storageStr, err
}

func DecryptKeystore(keystoreFilePath string, pwFilePath string) (*bridge_config.Wallet, error) {
	keyjson, err := os.ReadFile(keystoreFilePath)
	if err != nil {
		return nil, err
	}
	passphrase, err := os.ReadFile(pwFilePath)
	if err != nil {
		return nil, err
	}
	key, err := keystore.DecryptKey(keyjson, strings.TrimRight(string(passphrase), "\r\n"))
	if err != nil {
		return nil, err
	}
	return bridge_config.GetWallet(key.Address, &key.PrivateKey.PublicKey, key.PrivateKey), err
}
