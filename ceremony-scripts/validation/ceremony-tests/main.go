package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

var (
	gasPrice = big.NewInt(100)
	gasLimit = uint64(200000)
)

var failures int

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: ceremony-test <distribute|vote|create-contract>\n")
		os.Exit(1)
	}
	switch os.Args[1] {
	case "distribute":
		runDistribute()
	case "vote":
		runVote()
	case "create-contract":
		runCreateContract()
	default:
		fmt.Fprintf(os.Stderr, "Unknown subcommand: %s\n", os.Args[1])
		os.Exit(1)
	}
}

func check(label string, condition bool) {
	if condition {
		fmt.Printf("  PASS: %s\n", label)
	} else {
		fmt.Printf("  FAIL: %s\n", label)
		failures++
	}
}

func requireEnv(name string) string {
	val := os.Getenv(name)
	if val == "" {
		fmt.Fprintf(os.Stderr, "Missing required env var: %s\n", name)
		os.Exit(1)
	}
	return val
}

func loadKey(path string) (*ecdsa.PrivateKey, common.Address) {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read key file %s: %v\n", path, err)
		os.Exit(1)
	}
	hexKey := strings.TrimSpace(string(data))
	hexKey = strings.TrimPrefix(hexKey, "0x")

	key, err := crypto.HexToECDSA(hexKey)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse key from %s: %v\n", path, err)
		os.Exit(1)
	}
	addr := crypto.PubkeyToAddress(key.PublicKey)
	return key, addr
}

func dial(rpcURL string) (*ethclient.Client, *big.Int) {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to connect to %s: %v\n", rpcURL, err)
		os.Exit(1)
	}
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get chain ID: %v\n", err)
		os.Exit(1)
	}
	return client, chainID
}

func sendTx(client *ethclient.Client, chainID *big.Int, key *ecdsa.PrivateKey, to common.Address, value *big.Int, data []byte) *types.Receipt {
	from := crypto.PubkeyToAddress(key.PublicKey)
	nonce, err := client.PendingNonceAt(context.Background(), from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get nonce for %s: %v\n", from.Hex(), err)
		os.Exit(1)
	}

	tx := types.NewTransaction(nonce, to, value, gasLimit, gasPrice, data)
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), key)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to sign tx: %v\n", err)
		os.Exit(1)
	}

	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to send tx: %v\n", err)
		os.Exit(1)
	}

	receipt, err := bind.WaitMined(context.Background(), client, signedTx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed waiting for tx %s: %v\n", signedTx.Hash().Hex(), err)
		os.Exit(1)
	}
	return receipt
}

func ethCall(client *ethclient.Client, to common.Address, data []byte) []byte {
	result, err := client.CallContract(context.Background(), ethereum.CallMsg{
		To:   &to,
		Data: data,
	}, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "eth_call to %s failed: %v\n", to.Hex(), err)
		os.Exit(1)
	}
	return result
}

func balance(client *ethclient.Client, addr common.Address) *big.Int {
	bal, err := client.BalanceAt(context.Background(), addr, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get balance for %s: %v\n", addr.Hex(), err)
		os.Exit(1)
	}
	return bal
}
