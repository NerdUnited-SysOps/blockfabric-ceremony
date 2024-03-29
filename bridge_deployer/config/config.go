package config

import (
	"crypto/ecdsa"
	"encoding/hex"
	"math/big"

	bridge_logger "bridge-deployer/logging"

	"github.com/ethereum/go-ethereum/crypto"
	bridge "github.com/nerdcoresdk/neptune/pkg/contracts"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

var log = bridge_logger.GetInstance()

type Auth struct {
	Auth *bind.TransactOpts
}

type AwsInfo struct {
	AwsProfile       string
	AwsRegion        string
	AwsSecretKeyName string
}

type Wallet struct {
	Address common.Address
	Pub     *ecdsa.PublicKey
	Priv    *ecdsa.PrivateKey
}

type Bridge struct {
	Address     common.Address
	Approver    common.Address
	Notary      common.Address
	FeeReceiver common.Address
	Fee         big.Int
	Instance    *bridge.Bridge
}

type BridgeMinter struct {
	Address      common.Address
	Approver     common.Address
	Notary       common.Address
	TokenAddress common.Address
	Instance     *bridge.BridgeMinter
}

type Token struct {
	Address   common.Address
	Owner     common.Address
	Issuer    common.Address
	Name      string
	Symbol    string
	Decimals  int
	MaxSupply big.Int
	Instance  *bridge.Token
}

// Config contains all the necessary things for swapping the lockup contracts and moving the funds.
type Config struct {
	Brand              string
	Network            string
	ChainId            big.Int
	DeployerPrivateKey string
	Auth               *Auth
	EthClient          *ethclient.Client
	Bridge             *Bridge
	BridgeMinter       *BridgeMinter
	Token              *Token
	AwsInfo            *AwsInfo
}

func GetAuth(auth *bind.TransactOpts) *Auth {

	return &Auth{
		Auth: auth,
	}
}

func GetConfig(brand string, network string, chainId big.Int, deployerPrivateKey string, auth *Auth, client *ethclient.Client, bridge *Bridge, bridgeMinter *BridgeMinter, token *Token, awsInfo *AwsInfo) *Config {

	return &Config{
		Brand:              brand,
		Network:            network,
		ChainId:            chainId,
		DeployerPrivateKey: deployerPrivateKey,
		Auth:               auth,
		EthClient:          client,
		Bridge:             bridge,
		BridgeMinter:       bridgeMinter,
		Token:              token,
		AwsInfo:            awsInfo,
	}
}

func GetBridge(address common.Address, approver common.Address, notary common.Address, feeReceiver common.Address, fee big.Int) *Bridge {

	return &Bridge{
		Address:     address,
		Approver:    approver,
		Notary:      notary,
		FeeReceiver: feeReceiver,
		Fee:         fee,
	}
}

func GetBridgeMinter(address common.Address, approver common.Address, notary common.Address, tokenAddress common.Address) *BridgeMinter {

	return &BridgeMinter{
		Address:      address,
		Approver:     approver,
		Notary:       notary,
		TokenAddress: tokenAddress,
	}
}

func GetToken(owner common.Address, issuer common.Address, name string, symbol string, decimals int, maxSupply big.Int) *Token {

	return &Token{
		Owner:     owner,
		Issuer:    issuer,
		Name:      name,
		Symbol:    symbol,
		Decimals:  decimals,
		MaxSupply: maxSupply,
	}
}

func GetAwsInfo(profileName string, region string, secretKeyName string) *AwsInfo {

	return &AwsInfo{
		AwsProfile:       profileName,
		AwsRegion:        region,
		AwsSecretKeyName: secretKeyName,
	}
}

func GetWallet(address common.Address, pub *ecdsa.PublicKey, priv *ecdsa.PrivateKey) *Wallet {

	return &Wallet{
		Address: address,
		Pub:     pub,
		Priv:    priv,
	}
}

func (auth *Auth) Print() {
	log.Println("    From:                  ", auth.Auth.From)
	log.Println("    Nonce:                 ", auth.Auth.Nonce)
	log.Println("    Value:                 ", auth.Auth.Value)
	log.Println("    GasPrice:              ", auth.Auth.GasPrice)
	log.Println("    GasFeeCap:             ", auth.Auth.GasFeeCap)
	log.Println("    GasTipCap:             ", auth.Auth.GasTipCap)
	log.Println("    GasLimit:              ", auth.Auth.GasLimit)
	log.Println("    NoSend:                ", auth.Auth.NoSend)
}

func (bridge *Bridge) Print() {
	log.Println("    Address:               ", bridge.Address)
	log.Println("    Approver:              ", bridge.Approver)
	log.Println("    Notary:                ", bridge.Notary)
	log.Println("    FeeReceiver:           ", bridge.FeeReceiver)
	log.Println("    Fee:                   ", bridge.Fee)
}

func (bridge *BridgeMinter) Print() {
	log.Println("    Address:               ", bridge.Address)
	log.Println("    Approver:              ", bridge.Approver)
	log.Println("    Notary:                ", bridge.Notary)
	log.Println("    TokenAddress:          ", bridge.TokenAddress)
}

func (token *Token) Print() {
	log.Println("    Address:               ", token.Address)
	log.Println("    Owner:                 ", token.Owner)
	log.Println("    Issuer:                ", token.Issuer)
	log.Println("    Name:                  ", token.Name)
	log.Println("    Symbol:                ", token.Symbol)
	log.Println("    Decimals:              ", token.Decimals)
	log.Println("    MaxSupply:             ", token.MaxSupply)
}

func (wallet *Wallet) Print() {
	log.Println("    Address:               ", wallet.Address)
	log.Println("    PublicKey length:      ", wallet.Pub)
	log.Println("    PrivateKey length:     ", len(hex.EncodeToString(crypto.FromECDSA(wallet.Priv))))
}

func (config *Config) Print() {
	log.Println("Auth:                      ", config.Auth)
	config.Auth.Print()
	log.Println("")
	if config.Bridge != nil {
		log.Println("Bridge:")
		config.Bridge.Print()
		log.Println("")
	}
	if config.BridgeMinter != nil {
		log.Println("BridgeMinter:")
		config.BridgeMinter.Print()
		log.Println("")
	}
	if config.Token != nil {
		log.Println("Token:")
		config.Token.Print()
		log.Println("")
	}
	log.Println("ChainId:                   ", config.ChainId)
	log.Println("DeployerPrivateKey length: ", len(config.DeployerPrivateKey))
	log.Println("")
}
