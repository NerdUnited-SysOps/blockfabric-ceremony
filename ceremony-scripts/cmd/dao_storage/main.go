package main

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"math/big"
	"os"
	"regexp"
	"strings"

	"golang.org/x/crypto/sha3"
)

var hexAddrRe = regexp.MustCompile(`^0x[0-9A-Fa-f]{40}$`)

type entry struct {
	account        string
	validator      string
	validatorIndex int
	hasValidator   bool
}

type orderedMap struct {
	keys   []string
	values map[string]string
}

func newOrderedMap() *orderedMap {
	return &orderedMap{values: make(map[string]string)}
}

func (m *orderedMap) set(key, value string) {
	if _, exists := m.values[key]; !exists {
		m.keys = append(m.keys, key)
	}
	m.values[key] = value
}

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
		fmt.Fprintln(os.Stderr, "Usage: dao_storage <allowedAccountsAndValidators.txt>")
		os.Exit(1)
	}

	f, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	var entries []entry
	accUsed := make(map[string]bool)
	valUsed := make(map[string]bool)
	validatorIndex := 0

	scanner := bufio.NewScanner(f)
	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.Split(line, ",")
		acc := strings.TrimSpace(parts[0])

		if !hexAddrRe.MatchString(acc) {
			fmt.Fprintf(os.Stderr, "ERROR: Invalid address in line %d: '%s'\n", lineNum, acc)
			os.Exit(1)
		}
		if accUsed[acc] {
			fmt.Fprintln(os.Stderr, "ERROR: Accounts and Validators can only be used once")
			os.Exit(1)
		}
		accUsed[acc] = true

		if len(parts) == 1 {
			entries = append(entries, entry{account: acc})
		} else if len(parts) == 2 {
			vali := strings.TrimSpace(parts[1])
			if !hexAddrRe.MatchString(vali) {
				fmt.Fprintf(os.Stderr, "ERROR: Invalid address in line %d: '%s'\n", lineNum, vali)
				os.Exit(1)
			}
			if valUsed[vali] {
				fmt.Fprintln(os.Stderr, "ERROR: Accounts and Validators can only be used once")
				os.Exit(1)
			}
			valUsed[vali] = true
			entries = append(entries, entry{
				account:        acc,
				validator:      vali,
				validatorIndex: validatorIndex,
				hasValidator:   true,
			})
			validatorIndex++
		} else {
			fmt.Fprintln(os.Stderr, "ERROR: lines can only have 1 or 2 addresses")
			os.Exit(1)
		}
	}

	storage := newOrderedMap()

	// Slot 0: validator count
	storage.set(padLeft("0", 64), padLeft(fmt.Sprintf("%x", validatorIndex), 64))

	// Validator array entries stored at keccak256(slot(0))
	slot0Bytes, _ := hex.DecodeString(padLeft("0", 64))
	firstSlot := keccak256(slot0Bytes)
	firstSlotInt := new(big.Int).SetBytes(firstSlot)

	for _, e := range entries {
		if e.hasValidator {
			slot := new(big.Int).Add(firstSlotInt, big.NewInt(int64(e.validatorIndex)))
			slotHex := padLeft(fmt.Sprintf("%x", slot), 64)
			storage.set(slotHex, padLeft(strings.ToLower(e.validator[2:]), 64))
		}
	}

	// Allowed account mappings at keccak256(account | slot(1))
	pAllowed := padLeft("1", 64)
	for _, e := range entries {
		account := padLeft(strings.ToLower(e.account[2:]), 64)
		concat, _ := hex.DecodeString(account + pAllowed)
		slotHash := keccak256(concat)
		slotHex := padLeft(hex.EncodeToString(slotHash), 64)

		if e.hasValidator {
			value := fmt.Sprintf("%x0101", e.validatorIndex)
			storage.set(slotHex, padLeft(value, 64))
		} else {
			storage.set(slotHex, padLeft("01", 64))
		}
	}

	// Validator→account reverse mappings at keccak256(validator | slot(2))
	pV2A := padLeft("2", 64)
	for _, e := range entries {
		if e.hasValidator {
			validator := padLeft(strings.ToLower(e.validator[2:]), 64)
			concat, _ := hex.DecodeString(validator + pV2A)
			slotHash := keccak256(concat)
			slotHex := padLeft(hex.EncodeToString(slotHash), 64)
			storage.set(slotHex, padLeft(strings.ToLower(e.account[2:]), 64))
		}
	}

	// Slot 3: total allowed accounts count
	storage.set(padLeft("3", 64), padLeft(fmt.Sprintf("%x", len(entries)), 64))

	// Output matches JSON.stringify format with tab indentation,
	// with outer {} brackets stripped (matching the JS behavior)
	fmt.Println("\t\"<Address of Contract>\": {")
	fmt.Println("\t\t\"comment\": \"validator smart contract\",")
	fmt.Println("\t\t\"balance\": \"0x00\",")
	fmt.Println("\t\t\"code\": \"0x<Contract Code>\",")
	fmt.Println("\t\t\"storage\": {")

	for i, k := range storage.keys {
		comma := ","
		if i == len(storage.keys)-1 {
			comma = ""
		}
		fmt.Printf("\t\t\t\"%s\": \"%s\"%s\n", k, storage.values[k], comma)
	}

	fmt.Println("\t\t}")
	fmt.Println("\t}")
}
