package main

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"sort"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// DAO function selectors
var (
	selGetValidators                    = crypto.Keccak256([]byte("getValidators()"))[:4]
	selNumAllowedAccounts               = crypto.Keccak256([]byte("numAllowedAccounts()"))[:4]
	selVoteToAddAccountToAllowList      = crypto.Keccak256([]byte("voteToAddAccountToAllowList(address)"))[:4]
	selVoteToRemoveAccountFromAllowList = crypto.Keccak256([]byte("voteToRemoveAccountFromAllowList(address)"))[:4]
	selCountVotes                       = crypto.Keccak256([]byte("countVotes(address)"))[:4]
)

func runVote() {
	rpcURL := requireEnv("RPC_URL")
	daoAddr := common.HexToAddress(requireEnv("DAO_ADDRESS"))
	volumesDir := requireEnv("VOLUMES_DIR")

	client, chainID := dial(rpcURL)

	// Load issuer key (for funding)
	issuerKeyPath := filepath.Join(volumesDir, "volume2", "distributionIssuer", "privatekey")
	issuerKey, issuerAddr := loadKey(issuerKeyPath)
	fmt.Println("Issuer (funder):", issuerAddr.Hex())

	// Load validator account keys
	pattern := filepath.Join(volumesDir, "volume1", "besu-v-*", "account", "privatekey")
	keyFiles, err := filepath.Glob(pattern)
	if err != nil || len(keyFiles) == 0 {
		fmt.Fprintf(os.Stderr, "No validator account keys found at %s\n", pattern)
		os.Exit(1)
	}
	sort.Strings(keyFiles)

	type validatorAccount struct {
		key  *ecdsa.PrivateKey
		addr common.Address
		name string
	}

	var validators []validatorAccount
	for _, kf := range keyFiles {
		// Extract besu-v-N from path
		dir := filepath.Dir(filepath.Dir(kf))
		name := filepath.Base(dir)
		key, addr := loadKey(kf)
		validators = append(validators, validatorAccount{key, addr, name})
		fmt.Printf("  Loaded %s account: %s\n", name, addr.Hex())
	}
	fmt.Printf("Loaded %d validator accounts\n\n", len(validators))

	// Fund validator accounts if needed
	fmt.Println("--- Funding validator accounts ---")
	minBalance := big.NewInt(1_000_000_000) // 10^9 wei
	fundAmount := big.NewInt(10_000_000_000) // 10^10 wei
	for _, v := range validators {
		bal := balance(client, v.addr)
		if bal.Cmp(minBalance) < 0 {
			fmt.Printf("  Funding %s (%s) with %s wei...\n", v.name, v.addr.Hex(), fundAmount.String())
			receipt := sendTx(client, chainID, issuerKey, v.addr, fundAmount, nil)
			if receipt.Status != 1 {
				fmt.Fprintf(os.Stderr, "  Funding tx failed for %s\n", v.name)
				os.Exit(1)
			}
			fmt.Printf("  Funded %s (tx: %s)\n", v.name, receipt.TxHash.Hex())
		} else {
			fmt.Printf("  %s already funded (%s wei)\n", v.name, bal.String())
		}
	}

	// Read initial state
	fmt.Println("\n--- Initial state ---")
	initialValidators := getValidators(client, daoAddr)
	fmt.Printf("Validators: %d\n", len(initialValidators))
	initialAllowed := getNumAllowedAccounts(client, daoAddr)
	fmt.Printf("Allowed accounts: %d\n", initialAllowed)

	// Generate random test address
	testKey, err := crypto.GenerateKey()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to generate test key: %v\n", err)
		os.Exit(1)
	}
	testAddr := crypto.PubkeyToAddress(testKey.PublicKey)
	fmt.Printf("Test address: %s\n", testAddr.Hex())

	// Vote to ADD — need majority
	fmt.Println("\n--- Vote to ADD ---")
	majority := len(validators)/2 + 1
	fmt.Printf("Need %d/%d votes for majority\n", majority, len(validators))

	for i := 0; i < majority; i++ {
		v := validators[i]
		data := encodeAddressArg(selVoteToAddAccountToAllowList, testAddr)
		fmt.Printf("  %s voting to add...\n", v.name)
		receipt := sendTx(client, chainID, v.key, daoAddr, big.NewInt(0), data)
		if receipt.Status != 1 {
			fmt.Fprintf(os.Stderr, "  Vote tx failed for %s (status=%d)\n", v.name, receipt.Status)
			os.Exit(1)
		}
	}

	// Count votes
	fmt.Println("  Counting votes...")
	countData := encodeAddressArg(selCountVotes, testAddr)
	countReceipt := sendTx(client, chainID, validators[0].key, daoAddr, big.NewInt(0), countData)
	if countReceipt.Status != 1 {
		fmt.Fprintf(os.Stderr, "  countVotes tx failed (status=%d)\n", countReceipt.Status)
		os.Exit(1)
	}

	// Verify allowed accounts increased
	afterAddAllowed := getNumAllowedAccounts(client, daoAddr)
	fmt.Printf("Allowed accounts after add: %d\n", afterAddAllowed)
	check("Allowed accounts increased by 1", afterAddAllowed == initialAllowed+1)

	// Vote to REMOVE — recalculate majority (numAllowedAccounts increased)
	fmt.Println("\n--- Vote to REMOVE ---")
	removeMajority := int(afterAddAllowed)/2 + 1
	fmt.Printf("Need %d/%d votes for removal majority\n", removeMajority, afterAddAllowed)
	for i := 0; i < removeMajority; i++ {
		v := validators[i]
		data := encodeAddressArg(selVoteToRemoveAccountFromAllowList, testAddr)
		fmt.Printf("  %s voting to remove...\n", v.name)
		receipt := sendTx(client, chainID, v.key, daoAddr, big.NewInt(0), data)
		if receipt.Status != 1 {
			fmt.Fprintf(os.Stderr, "  Vote tx failed for %s (status=%d)\n", v.name, receipt.Status)
			os.Exit(1)
		}
	}

	// Count votes for removal
	fmt.Println("  Counting votes...")
	countReceipt = sendTx(client, chainID, validators[0].key, daoAddr, big.NewInt(0), countData)
	if countReceipt.Status != 1 {
		fmt.Fprintf(os.Stderr, "  countVotes tx failed (status=%d)\n", countReceipt.Status)
		os.Exit(1)
	}

	// Verify counts restored
	afterRemoveAllowed := getNumAllowedAccounts(client, daoAddr)
	fmt.Printf("Allowed accounts after remove: %d\n", afterRemoveAllowed)
	check("Allowed accounts restored", afterRemoveAllowed == initialAllowed)

	// Verify validators unchanged
	finalValidators := getValidators(client, daoAddr)
	check("Validators unchanged", len(finalValidators) == len(initialValidators))

	// Summary
	fmt.Println("\n===========================")
	if failures == 0 {
		fmt.Println("Vote test PASSED")
	} else {
		fmt.Printf("Vote test FAILED (%d check(s) failed)\n", failures)
	}
	fmt.Println("===========================")

	if failures > 0 {
		os.Exit(1)
	}
}

func getValidators(client *ethclient.Client, dao common.Address) []common.Address {
	result := ethCall(client, dao, selGetValidators)
	return decodeAddressArray(result)
}

func getNumAllowedAccounts(client *ethclient.Client, dao common.Address) int64 {
	result := ethCall(client, dao, selNumAllowedAccounts)
	n := new(big.Int).SetBytes(result)
	return n.Int64()
}

func encodeAddressArg(selector []byte, addr common.Address) []byte {
	padded := common.LeftPadBytes(addr.Bytes(), 32)
	data := make([]byte, 4+32)
	copy(data[:4], selector)
	copy(data[4:], padded)
	return data
}

func decodeAddressArray(data []byte) []common.Address {
	if len(data) < 64 {
		return nil
	}
	// ABI-encoded dynamic array: offset (32 bytes) + length (32 bytes) + elements
	offset := new(big.Int).SetBytes(data[:32]).Int64()
	if int(offset)+32 > len(data) {
		return nil
	}
	length := new(big.Int).SetBytes(data[offset : offset+32]).Int64()
	var addrs []common.Address
	for i := int64(0); i < length; i++ {
		start := offset + 32 + i*32
		if int(start)+32 > len(data) {
			break
		}
		addrs = append(addrs, common.BytesToAddress(data[start:start+32]))
	}
	return addrs
}
