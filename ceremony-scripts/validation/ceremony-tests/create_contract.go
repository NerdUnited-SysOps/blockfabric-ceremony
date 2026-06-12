package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Init bytecode exercising Shanghai + Cancun opcodes:
//
//	PUSH0           5f        EIP-3855 (Shanghai)
//	PUSH1 0x42      60 42     test value
//	PUSH0           5f        key = 0
//	TSTORE          5c        EIP-1153 (Cancun): transient_storage[0] = 0x42
//	PUSH0           5f        key = 0
//	TLOAD           5d        EIP-1153 (Cancun): push transient_storage[0]
//	PUSH0           5f        offset 0
//	MSTORE          52        memory[0] = 0x42
//	PUSH1 0x20      60 20     length 32
//	PUSH0           5f        src 0
//	PUSH1 0x20      60 20     dst 32
//	MCOPY           5e        EIP-5656 (Cancun): copy memory[0:32] → memory[32:64]
//	POP             50        clean stack
//	PUSH2 0x5f00    61 5f 00  runtime bytecode (PUSH0; STOP)
//	PUSH0           5f        offset 0
//	MSTORE          52        store at memory[0]
//	PUSH1 0x02      60 02     runtime size = 2
//	PUSH1 0x1e      60 1e     offset 30 (MSTORE right-pads)
//	RETURN          f3        deploy runtime
var initBytecodeHex = "5f60425f5c5f5d5f5260205f60205e50615f005f526002601ef3"

// Expected deployed runtime: PUSH0 + STOP
var expectedRuntimeHex = "5f00"

func deployContract(client *ethclient.Client, chainID *big.Int, key *ecdsa.PrivateKey) *types.Receipt {
	from := crypto.PubkeyToAddress(key.PublicKey)
	nonce, err := client.PendingNonceAt(context.Background(), from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get nonce for %s: %v\n", from.Hex(), err)
		os.Exit(1)
	}

	initCode, err := hex.DecodeString(initBytecodeHex)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to decode init bytecode: %v\n", err)
		os.Exit(1)
	}

	tx := types.NewContractCreation(nonce, big.NewInt(0), gasLimit, gasPrice, initCode)
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

func runCreateContract() {
	rpcURL := requireEnv("RPC_URL")
	deployerKeyPath := requireEnv("DEPLOYER_KEY_PATH")

	client, chainID := dial(rpcURL)

	deployerKey, deployerAddr := loadKey(deployerKeyPath)
	fmt.Println("Deployer address:", deployerAddr.Hex())

	fmt.Println("\n--- Contract deployment (Shanghai + Cancun opcodes) ---")
	fmt.Println("Init bytecode:", initBytecodeHex)
	fmt.Println("Deploying...")

	receipt := deployContract(client, chainID, deployerKey)
	fmt.Println("TX hash:", receipt.TxHash.Hex())
	fmt.Println("Block:", receipt.BlockNumber.Uint64())
	fmt.Println("Gas used:", receipt.GasUsed)

	// Check 1: TX status is SUCCESS
	check("TX status is SUCCESS", receipt.Status == 1)

	// Check 2: Contract address present
	contractAddr := receipt.ContractAddress
	fmt.Println("Contract address:", contractAddr.Hex())
	check("Contract address present", contractAddr != common.Address{})

	// Check 3: eth_getCode returns non-empty
	fmt.Println("\n--- Code verification ---")
	code, err := client.CodeAt(context.Background(), contractAddr, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get code at %s: %v\n", contractAddr.Hex(), err)
		os.Exit(1)
	}
	fmt.Printf("Deployed code: 0x%x\n", code)
	check("Deployed code is non-empty", len(code) > 0)

	// Check 4: Deployed code matches expected runtime
	expectedRuntime, _ := hex.DecodeString(expectedRuntimeHex)
	codeMatch := len(code) == len(expectedRuntime)
	if codeMatch {
		for i := range code {
			if code[i] != expectedRuntime[i] {
				codeMatch = false
				break
			}
		}
	}
	check("Deployed code matches expected (0x"+expectedRuntimeHex+")", codeMatch)

	// Summary
	fmt.Println("\n===========================")
	if failures == 0 {
		fmt.Println("Create contract test PASSED")
	} else {
		fmt.Printf("Create contract test FAILED (%d check(s) failed)\n", failures)
	}
	fmt.Println("===========================")

	if failures > 0 {
		os.Exit(1)
	}
}
