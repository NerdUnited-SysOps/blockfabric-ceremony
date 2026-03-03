package main

import (
	"fmt"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

var distributionContract = common.HexToAddress("0x8Be503bcdEd90ED42Eff31f56199399B2b0154CA")

// Function selectors
var (
	selIssuer     = crypto.Keccak256([]byte("issuer()"))[:4]
	selDistribute = crypto.Keccak256([]byte("distribute(address[],uint256[])"))[:4]
)

// Event topic
var topicDistributed = crypto.Keccak256Hash([]byte("Distributed(address,uint256)"))

func runDistribute() {
	rpcURL := requireEnv("RPC_URL")
	issuerKeyPath := requireEnv("ISSUER_KEY_PATH")
	recipientKeyPath := requireEnv("RECIPIENT_KEY_PATH")

	client, chainID := dial(rpcURL)

	issuerKey, issuerAddr := loadKey(issuerKeyPath)
	_, recipientAddr := loadKey(recipientKeyPath)

	fmt.Println("Issuer address:", issuerAddr.Hex())
	fmt.Println("Recipient (validator 1 account):", recipientAddr.Hex())

	// 1. Verify on-chain issuer matches wallet
	result := ethCall(client, distributionContract, selIssuer)
	fmt.Println("\n--- Issuer verification ---")
	onChainIssuer := common.BytesToAddress(result)
	fmt.Println("On-chain issuer:", onChainIssuer.Hex())
	check("Issuer matches wallet", onChainIssuer == issuerAddr)

	// 2. Get recipient balance before
	balBefore := balance(client, recipientAddr)
	fmt.Println("\n--- Distribution call ---")
	fmt.Println("Recipient balance before:", balBefore.String())

	// 3. Call distribute([recipient], [1000])
	amount := big.NewInt(1000)
	fmt.Printf("Calling distribute([%s], [%s])...\n", recipientAddr.Hex(), amount.String())

	data := encodeDistribute(recipientAddr, amount)
	receipt := sendTx(client, chainID, issuerKey, distributionContract, big.NewInt(0), data)
	fmt.Println("TX hash:", receipt.TxHash.Hex())
	fmt.Println("Block:", receipt.BlockNumber.Uint64())
	fmt.Println("Gas used:", receipt.GasUsed)

	// 4. Check tx status
	check("TX status is SUCCESS", receipt.Status == 1)

	// 5. Check Distributed event
	fmt.Println("\n--- Event verification ---")
	eventFound := false
	for _, log := range receipt.Logs {
		if len(log.Topics) >= 2 && log.Topics[0] == topicDistributed {
			eventRecipient := common.BytesToAddress(log.Topics[1].Bytes())
			eventAmount := new(big.Int).SetBytes(log.Data)
			fmt.Printf("  Event: recipient=%s, amount=%s\n", eventRecipient.Hex(), eventAmount.String())
			eventFound = true
		}
	}
	check("Distributed event emitted", eventFound)

	// 6. Verify balance increase
	fmt.Println("\n--- Balance verification ---")
	balAfter := balance(client, recipientAddr)
	fmt.Println("Recipient balance after:", balAfter.String())
	diff := new(big.Int).Sub(balAfter, balBefore)
	fmt.Println("Balance increase:", diff.String())
	check("Balance increased by expected amount", diff.Cmp(amount) == 0)

	// Summary
	fmt.Println("\n===========================")
	if failures == 0 {
		fmt.Println("Distribution test PASSED")
	} else {
		fmt.Printf("Distribution test FAILED (%d check(s) failed)\n", failures)
	}
	fmt.Println("===========================")

	if failures > 0 {
		os.Exit(1)
	}
}

func encodeDistribute(recipient common.Address, amount *big.Int) []byte {
	addrArrayType, _ := abi.NewType("address[]", "", nil)
	uintArrayType, _ := abi.NewType("uint256[]", "", nil)

	args := abi.Arguments{
		{Type: addrArrayType},
		{Type: uintArrayType},
	}

	packed, err := args.Pack(
		[]common.Address{recipient},
		[]*big.Int{amount},
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to ABI-encode distribute args: %v\n", err)
		os.Exit(1)
	}

	return append(selDistribute, packed...)
}
