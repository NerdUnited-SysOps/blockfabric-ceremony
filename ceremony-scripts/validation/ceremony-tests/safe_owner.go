package main

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"
	"sort"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Contract addresses
var (
	lockupAddr = common.HexToAddress("0x47e9Fbef8C83A1714F1951F142132E6e90F5fa5D")
	distAddr   = common.HexToAddress("0x8Be503bcdEd90ED42Eff31f56199399B2b0154CA")
)

// Lockup function selectors
var (
	selSetPaused     = crypto.Keccak256([]byte("setPaused(bool)"))[:4]
	selSetDailyLimit = crypto.Keccak256([]byte("setDailyLimit(uint256)"))[:4]
	selSetIssuer     = crypto.Keccak256([]byte("setIssuer(address)"))[:4]
	selPaused        = crypto.Keccak256([]byte("paused()"))[:4]
	selDailyLimit    = crypto.Keccak256([]byte("effectiveDailyLimit()"))[:4]
	selLockupIssuer  = crypto.Keccak256([]byte("issuer()"))[:4]
	selDistIssuer    = crypto.Keccak256([]byte("issuer()"))[:4]
)

// Safe function selectors and constants
var (
	selExecTransaction = crypto.Keccak256([]byte("execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)"))[:4]
	selNonce           = crypto.Keccak256([]byte("nonce()"))[:4]
	selGetOwners       = crypto.Keccak256([]byte("getOwners()"))[:4]
	selGetThreshold    = crypto.Keccak256([]byte("getThreshold()"))[:4]

	// EIP-712 domain separator type hash
	domainSeparatorTypeHash = crypto.Keccak256([]byte("EIP712Domain(uint256 chainId,address verifyingContract)"))
	// Safe tx type hash
	safeTxTypeHash = crypto.Keccak256([]byte("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"))
)

// loadSafeEnv loads common Safe test environment
func loadSafeEnv() (rpcURL string, safeAddr common.Address, keys []*ecdsa.PrivateKey, addrs []common.Address, funderKey *ecdsa.PrivateKey) {
	rpcURL = requireEnv("RPC_URL")
	safeAddr = common.HexToAddress(requireEnv("SAFE_PROXY_ADDRESS"))

	keyPaths := []string{
		requireEnv("SAFE_OWNER_1_KEY_PATH"),
		requireEnv("SAFE_OWNER_2_KEY_PATH"),
		requireEnv("SAFE_OWNER_3_KEY_PATH"),
	}

	for _, p := range keyPaths {
		k, a := loadKey(p)
		keys = append(keys, k)
		addrs = append(addrs, a)
	}

	funderKey, _ = loadKey(requireEnv("FUNDER_KEY_PATH"))
	return
}

// fundIfNeeded sends gas money from funder to addr if balance is zero
func fundIfNeeded(client *ethclient.Client, chainID *big.Int, funderKey *ecdsa.PrivateKey, addr common.Address) {
	bal := balance(client, addr)
	if bal.Sign() > 0 {
		return
	}
	gasAmount := new(big.Int).Mul(big.NewInt(1e15), big.NewInt(10)) // 0.01 tokens
	fmt.Printf("  Funding %s with %s wei for gas...\n", addr.Hex(), gasAmount.String())
	receipt := sendTx(client, chainID, funderKey, addr, gasAmount, nil)
	check("Funding tx succeeded", receipt.Status == 1)
}

// computeSafeTxHash computes the EIP-712 hash for a Safe transaction
func computeSafeTxHash(chainID *big.Int, safeAddr common.Address, to common.Address, value *big.Int, data []byte, nonce *big.Int) common.Hash {
	// Domain separator
	domainSep := crypto.Keccak256(
		domainSeparatorTypeHash,
		common.LeftPadBytes(chainID.Bytes(), 32),
		common.LeftPadBytes(safeAddr.Bytes(), 32),
	)

	// SafeTx hash
	dataHash := crypto.Keccak256(data)
	safeTxHash := crypto.Keccak256(
		safeTxTypeHash,
		common.LeftPadBytes(to.Bytes(), 32),                            // to
		common.LeftPadBytes(value.Bytes(), 32),                          // value
		dataHash,                                                        // keccak256(data)
		common.LeftPadBytes([]byte{0}, 32),                              // operation (CALL=0)
		common.LeftPadBytes(big.NewInt(0).Bytes(), 32),                  // safeTxGas
		common.LeftPadBytes(big.NewInt(0).Bytes(), 32),                  // baseGas
		common.LeftPadBytes(big.NewInt(0).Bytes(), 32),                  // gasPrice
		common.LeftPadBytes(common.Address{}.Bytes(), 32),               // gasToken (0x0)
		common.LeftPadBytes(common.Address{}.Bytes(), 32),               // refundReceiver (0x0)
		common.LeftPadBytes(nonce.Bytes(), 32),                          // nonce
	)

	// EIP-712 encoding: \x19\x01 ++ domainSeparator ++ safeTxHash
	return crypto.Keccak256Hash(
		[]byte{0x19, 0x01},
		domainSep,
		safeTxHash,
	)
}

// signSafeTx signs a Safe transaction hash with multiple keys and returns packed signatures
// Signatures must be sorted by signer address (ascending)
func signSafeTx(txHash common.Hash, keys []*ecdsa.PrivateKey, count int) []byte {
	type sigEntry struct {
		addr common.Address
		sig  []byte
	}

	var entries []sigEntry
	for i := 0; i < count && i < len(keys); i++ {
		sig, err := crypto.Sign(txHash.Bytes(), keys[i])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to sign Safe tx: %v\n", err)
			os.Exit(1)
		}
		// Ethereum signature: adjust V from 0/1 to 27/28
		sig[64] += 27
		entries = append(entries, sigEntry{
			addr: crypto.PubkeyToAddress(keys[i].PublicKey),
			sig:  sig,
		})
	}

	// Sort by address (Safe requires ascending order)
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].addr.Hex() < entries[j].addr.Hex()
	})

	var packed []byte
	for _, e := range entries {
		packed = append(packed, e.sig...)
	}
	return packed
}

// encodeExecTransaction ABI-encodes a Safe execTransaction call
func encodeExecTransaction(to common.Address, value *big.Int, data []byte, signatures []byte) []byte {
	addressType, _ := abi.NewType("address", "", nil)
	uint256Type, _ := abi.NewType("uint256", "", nil)
	bytesType, _ := abi.NewType("bytes", "", nil)
	uint8Type, _ := abi.NewType("uint8", "", nil)

	args := abi.Arguments{
		{Type: addressType},  // to
		{Type: uint256Type},  // value
		{Type: bytesType},    // data
		{Type: uint8Type},    // operation (CALL=0)
		{Type: uint256Type},  // safeTxGas
		{Type: uint256Type},  // baseGas
		{Type: uint256Type},  // gasPrice
		{Type: addressType},  // gasToken
		{Type: addressType},  // refundReceiver
		{Type: bytesType},    // signatures
	}

	packed, err := args.Pack(
		to,
		value,
		data,
		uint8(0),          // CALL
		big.NewInt(0),     // safeTxGas
		big.NewInt(0),     // baseGas
		big.NewInt(0),     // gasPrice
		common.Address{},  // gasToken (ETH)
		common.Address{},  // refundReceiver
		signatures,
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to encode execTransaction: %v\n", err)
		os.Exit(1)
	}

	return append(selExecTransaction, packed...)
}

// execSafeTx constructs and sends a Safe multisig transaction
func execSafeTx(rpcURL string, safeAddr common.Address, keys []*ecdsa.PrivateKey, threshold int, to common.Address, innerData []byte, funderKey *ecdsa.PrivateKey) {
	client, chainID := dial(rpcURL)

	// Fund the sender (keys[0]) if they have no gas
	fundIfNeeded(client, chainID, funderKey, crypto.PubkeyToAddress(keys[0].PublicKey))

	// Get Safe nonce
	nonceResult := ethCall(client, safeAddr, selNonce)
	nonce := new(big.Int).SetBytes(nonceResult)
	fmt.Printf("  Safe nonce: %s\n", nonce.String())

	// Compute EIP-712 hash
	txHash := computeSafeTxHash(chainID, safeAddr, to, big.NewInt(0), innerData, nonce)
	fmt.Printf("  Safe tx hash: %s\n", txHash.Hex())

	// Sign with threshold number of keys
	signatures := signSafeTx(txHash, keys, threshold)
	fmt.Printf("  Signatures: %d of %d\n", threshold, len(keys))

	// Encode execTransaction
	execData := encodeExecTransaction(to, big.NewInt(0), innerData, signatures)

	// Send from first signer (any EOA can submit)
	receipt := sendTx(client, chainID, keys[0], safeAddr, big.NewInt(0), execData)
	fmt.Printf("  TX hash: %s\n", receipt.TxHash.Hex())
	fmt.Printf("  Block: %d\n", receipt.BlockNumber.Uint64())
	fmt.Printf("  Gas used: %d\n", receipt.GasUsed)
	check("TX status is SUCCESS", receipt.Status == 1)
}

// ============================================================
// Test: Lockup setPaused
// ============================================================

func runTestLockupSetPaused() {
	fmt.Println("=== Test: Lockup setPaused via Safe multisig ===\n")
	rpcURL, safeAddr, keys, _, funderKey := loadSafeEnv()
	client, _ := dial(rpcURL)

	// Read current paused state
	result := ethCall(client, lockupAddr, selPaused)
	wasPaused := result[31] != 0
	fmt.Printf("Current paused state: %v\n", wasPaused)

	// Toggle it
	newState := !wasPaused
	fmt.Printf("Setting paused to: %v\n\n", newState)

	// Encode setPaused(bool)
	boolType, _ := abi.NewType("bool", "", nil)
	args := abi.Arguments{{Type: boolType}}
	packed, _ := args.Pack(newState)
	innerData := append(selSetPaused, packed...)

	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	// Verify state changed
	fmt.Println("\n--- Verification ---")
	result = ethCall(client, lockupAddr, selPaused)
	isPaused := result[31] != 0
	fmt.Printf("Paused state after: %v\n", isPaused)
	check("Paused state toggled", isPaused == newState)

	// Toggle back
	fmt.Printf("\nRestoring paused to: %v\n", wasPaused)
	packed, _ = args.Pack(wasPaused)
	innerData = append(selSetPaused, packed...)
	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	result = ethCall(client, lockupAddr, selPaused)
	isPaused = result[31] != 0
	check("Paused state restored", isPaused == wasPaused)

	printSummary("Lockup setPaused")
}

// ============================================================
// Test: Lockup setDailyLimit
// ============================================================

func runTestLockupSetDailyLimit() {
	fmt.Println("=== Test: Lockup setDailyLimit via Safe multisig ===\n")
	rpcURL, safeAddr, keys, _, funderKey := loadSafeEnv()
	client, _ := dial(rpcURL)

	// Read current effective daily limit
	result := ethCall(client, lockupAddr, selDailyLimit)
	originalLimit := new(big.Int).SetBytes(result)
	fmt.Printf("Current effective daily limit: %s\n", originalLimit.String())

	// Set to a test value (original + 1)
	testLimit := new(big.Int).Add(originalLimit, big.NewInt(1))
	fmt.Printf("Setting daily limit to: %s\n\n", testLimit.String())

	// Encode setDailyLimit(uint256)
	uint256Type, _ := abi.NewType("uint256", "", nil)
	args := abi.Arguments{{Type: uint256Type}}
	packed, _ := args.Pack(testLimit)
	innerData := append(selSetDailyLimit, packed...)

	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	// Verify
	fmt.Println("\n--- Verification ---")
	result = ethCall(client, lockupAddr, selDailyLimit)
	newLimit := new(big.Int).SetBytes(result)
	fmt.Printf("Effective daily limit after: %s\n", newLimit.String())
	check("Daily limit updated", newLimit.Cmp(testLimit) == 0)

	// Restore
	fmt.Printf("\nRestoring daily limit to: %s\n", originalLimit.String())
	packed, _ = args.Pack(originalLimit)
	innerData = append(selSetDailyLimit, packed...)
	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	result = ethCall(client, lockupAddr, selDailyLimit)
	restoredLimit := new(big.Int).SetBytes(result)
	check("Daily limit restored", restoredLimit.Cmp(originalLimit) == 0)

	printSummary("Lockup setDailyLimit")
}

// ============================================================
// Test: Lockup setIssuer
// ============================================================

func runTestLockupSetIssuer() {
	fmt.Println("=== Test: Lockup setIssuer via Safe multisig ===\n")
	rpcURL, safeAddr, keys, addrs, funderKey := loadSafeEnv()
	client, _ := dial(rpcURL)

	// Read current issuer
	result := ethCall(client, lockupAddr, selLockupIssuer)
	originalIssuer := common.BytesToAddress(result)
	fmt.Printf("Current lockup issuer: %s\n", originalIssuer.Hex())

	// Set to a test address (first Safe owner)
	testIssuer := addrs[0]
	fmt.Printf("Setting issuer to: %s\n\n", testIssuer.Hex())

	// Encode setIssuer(address)
	addressType, _ := abi.NewType("address", "", nil)
	args := abi.Arguments{{Type: addressType}}
	packed, _ := args.Pack(testIssuer)
	innerData := append(selSetIssuer, packed...)

	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	// Verify
	fmt.Println("\n--- Verification ---")
	result = ethCall(client, lockupAddr, selLockupIssuer)
	newIssuer := common.BytesToAddress(result)
	fmt.Printf("Lockup issuer after: %s\n", newIssuer.Hex())
	check("Issuer updated", newIssuer == testIssuer)

	// Restore
	fmt.Printf("\nRestoring issuer to: %s\n", originalIssuer.Hex())
	packed, _ = args.Pack(originalIssuer)
	innerData = append(selSetIssuer, packed...)
	execSafeTx(rpcURL, safeAddr, keys, 2, lockupAddr, innerData, funderKey)

	result = ethCall(client, lockupAddr, selLockupIssuer)
	restoredIssuer := common.BytesToAddress(result)
	check("Issuer restored", restoredIssuer == originalIssuer)

	printSummary("Lockup setIssuer")
}

// ============================================================
// Test: Distribution setIssuer
// ============================================================

func runTestDistributionSetIssuer() {
	fmt.Println("=== Test: Distribution setIssuer via Safe multisig ===\n")
	rpcURL, safeAddr, keys, addrs, funderKey := loadSafeEnv()
	client, _ := dial(rpcURL)

	// Read current issuer
	result := ethCall(client, distAddr, selDistIssuer)
	originalIssuer := common.BytesToAddress(result)
	fmt.Printf("Current distribution issuer: %s\n", originalIssuer.Hex())

	// Set to a test address (first Safe owner)
	testIssuer := addrs[0]
	fmt.Printf("Setting issuer to: %s\n\n", testIssuer.Hex())

	// Encode setIssuer(address)
	addressType, _ := abi.NewType("address", "", nil)
	args := abi.Arguments{{Type: addressType}}
	packed, _ := args.Pack(testIssuer)
	innerData := append(selSetIssuer, packed...)

	execSafeTx(rpcURL, safeAddr, keys, 2, distAddr, innerData, funderKey)

	// Verify
	fmt.Println("\n--- Verification ---")
	result = ethCall(client, distAddr, selDistIssuer)
	newIssuer := common.BytesToAddress(result)
	fmt.Printf("Distribution issuer after: %s\n", newIssuer.Hex())
	check("Issuer updated", newIssuer == testIssuer)

	// Restore
	fmt.Printf("\nRestoring issuer to: %s\n", originalIssuer.Hex())
	packed, _ = args.Pack(originalIssuer)
	innerData = append(selSetIssuer, packed...)
	execSafeTx(rpcURL, safeAddr, keys, 2, distAddr, innerData, funderKey)

	result = ethCall(client, distAddr, selDistIssuer)
	restoredIssuer := common.BytesToAddress(result)
	check("Issuer restored", restoredIssuer == originalIssuer)

	printSummary("Distribution setIssuer")
}

func printSummary(testName string) {
	fmt.Println("\n===========================")
	if failures == 0 {
		fmt.Printf("%s test PASSED\n", testName)
	} else {
		fmt.Printf("%s test FAILED (%d check(s) failed)\n", testName, failures)
	}
	fmt.Println("===========================")
	if failures > 0 {
		os.Exit(1)
	}
}
