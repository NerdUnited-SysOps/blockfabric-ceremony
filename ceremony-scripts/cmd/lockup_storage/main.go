package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/sha3"
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

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: lockup_storage <address1> [address2] ...")
		os.Exit(1)
	}

	storageSlot := "0000000000000000000000000000000000000000000000000000000000000001"
	var parts []string

	for _, addr := range os.Args[1:] {
		cleaned := strings.ToLower(strings.TrimPrefix(addr, "0x"))
		paddedAccount := padLeft(cleaned, 64)
		concat, _ := hex.DecodeString(paddedAccount + storageSlot)
		slot := hex.EncodeToString(keccak256(concat))
		parts = append(parts, fmt.Sprintf("\"0x%s\": \"01\"", slot))
	}

	fmt.Println(strings.Join(parts, ", "))
}
