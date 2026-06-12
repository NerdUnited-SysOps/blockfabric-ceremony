package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/sha3"
)

// Gnosis Safe v1.3.0 storage layout:
//   slot 0: singleton (address)         - from Singleton.sol
//   slot 1: modules (mapping)           - from ModuleManager.sol
//   slot 2: owners (mapping)            - from OwnerManager.sol
//   slot 3: ownerCount (uint256)        - from OwnerManager.sol
//   slot 4: threshold (uint256)         - from OwnerManager.sol
//   slot 5: nonce (uint256)             - from GnosisSafe.sol

const (
	singletonSlot  = "0000000000000000000000000000000000000000000000000000000000000000"
	modulesSlot    = "0000000000000000000000000000000000000000000000000000000000000001"
	ownersSlot     = "0000000000000000000000000000000000000000000000000000000000000002"
	ownerCountSlot = "0000000000000000000000000000000000000000000000000000000000000003"
	thresholdSlot  = "0000000000000000000000000000000000000000000000000000000000000004"

	sentinel = "0000000000000000000000000000000000000000000000000000000000000001"
)

func keccak256(data []byte) []byte {
	h := sha3.NewLegacyKeccak256()
	h.Write(data)
	return h.Sum(nil)
}

func padLeft(s string, length int) string {
	if len(s) >= length {
		return s
	}
	return strings.Repeat("0", length-len(s)) + s
}

func padAddress(addr string) string {
	cleaned := strings.ToLower(strings.TrimPrefix(addr, "0x"))
	return padLeft(cleaned, 64)
}

// mappingSlot computes keccak256(key || mappingPosition) for a mapping entry
func mappingSlot(key string, mappingPos string) string {
	concat, _ := hex.DecodeString(key + mappingPos)
	return hex.EncodeToString(keccak256(concat))
}

func main() {
	if len(os.Args) < 4 {
		fmt.Fprintln(os.Stderr, "Usage: safe_storage <singleton_address> <threshold> <owner1> <owner2> [owner3] ...")
		os.Exit(1)
	}

	singletonAddr := os.Args[1]
	threshold := os.Args[2]
	owners := os.Args[3:]

	var parts []string

	// Slot 0: singleton address
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", singletonSlot, padAddress(singletonAddr)))

	// Slot 1 (modules mapping): sentinel -> sentinel (no modules enabled)
	modulesSentinelSlot := mappingSlot(sentinel, modulesSlot)
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", modulesSentinelSlot, sentinel))

	// Slot 2 (owners mapping): linked list SENTINEL -> owner1 -> owner2 -> ... -> SENTINEL
	// First entry: owners[SENTINEL] = owner1
	ownerSlot := mappingSlot(sentinel, ownersSlot)
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", ownerSlot, padAddress(owners[0])))

	// Middle entries: owners[ownerN] = ownerN+1
	for i := 0; i < len(owners)-1; i++ {
		ownerSlot = mappingSlot(padAddress(owners[i]), ownersSlot)
		parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", ownerSlot, padAddress(owners[i+1])))
	}

	// Last entry: owners[lastOwner] = SENTINEL
	ownerSlot = mappingSlot(padAddress(owners[len(owners)-1]), ownersSlot)
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", ownerSlot, sentinel))

	// Slot 3: ownerCount
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", ownerCountSlot, padLeft(fmt.Sprintf("%x", len(owners)), 64)))

	// Slot 4: threshold
	parts = append(parts, fmt.Sprintf("\"%s\": \"%s\"", thresholdSlot, padLeft(threshold, 64)))

	fmt.Println("{ " + strings.Join(parts, ", ") + " }")
}
