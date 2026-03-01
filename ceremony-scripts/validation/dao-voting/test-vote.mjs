#!/usr/bin/env node
// DAO validator vote-in/vote-out test
// Tests the full allowlist voting lifecycle on the DAO contract:
//   1. Fund validator accounts from distribution issuer
//   2. Vote to add a new account to the allowlist (majority required)
//   3. Count votes to finalize the add
//   4. Vote to remove the account (majority required)
//   5. Count votes to finalize the removal
//   6. Verify validator set unchanged
//
// DAO Dual Key Model:
//   The DAO contract maintains two separate address sets:
//
//   - allowedAccounts (account keys) — from volume1/{host}/account/privatekey
//     These are the addresses that can VOTE (call voteToAdd/Remove, countVotes).
//     Stored in the contract's allowedAccounts mapping (slot 1).
//
//   - validators (node keys) — from volume1/{host}/node/privatekey
//     These are the addresses that PRODUCE BLOCKS in QBFT consensus.
//     Stored in the contract's validators array (slot 0).
//     Returned by getValidators().
//
//   The two key pairs are generated independently during the ceremony.
//   generate_dao_storage.sh maps them together in genesis storage via the
//   validatorToAccount mapping (slot 2).
//
//   This test uses account/privatekey to send vote transactions because
//   only allowedAccount addresses pass the senderIsAllowed modifier.
//
// Gas pricing:
//   ethers.js EIP-1559 fee estimation produces unreasonable values on
//   private QBFT chains with low activity. We use explicit legacy gasPrice
//   and gasLimit to avoid this. min-gas-price on validators is 1.

import { ethers } from "ethers";
import { readFileSync, existsSync } from "fs";
import { resolve } from "path";

const ABI = [
  "function getValidators() view returns (address[])",
  "function numAllowedAccounts() view returns (uint)",
  "function voteToAddAccountToAllowList(address account)",
  "function voteToRemoveAccountFromAllowList(address account)",
  "function countVotes(address account) returns (uint numVotes, uint requiredVotes, bool electionSucceeded)",
];

function usage() {
  console.error("Usage: node test-vote.mjs <rpc_url> <chain_id> <dao_address> <ceremony_artifacts_dir>");
  console.error("  rpc_url:              e.g. http://192.168.3.232:8669");
  console.error("  chain_id:             e.g. 5966");
  console.error("  dao_address:          e.g. 0x5a443704dd4B594B382c22a083e2BD3090A6feF3");
  console.error("  ceremony_artifacts:   path to ceremony-artifacts/volumes/");
  process.exit(1);
}

async function main() {
  const [,, rpcUrl, chainIdStr, daoAddress, artifactsDir] = process.argv;
  if (!rpcUrl || !chainIdStr || !daoAddress || !artifactsDir) usage();

  const chainId = parseInt(chainIdStr);
  const provider = new ethers.JsonRpcProvider(rpcUrl, chainId);

  // Discover validator count from volume1 dirs
  const vol1 = resolve(artifactsDir, "volume1");
  const vol2 = resolve(artifactsDir, "volume2");

  // Load distribution issuer (has genesis balance for gas funding)
  const issuerKeyPath = resolve(vol2, "distributionIssuer/privatekey");
  if (!existsSync(issuerKeyPath)) {
    console.error(`Distribution issuer key not found: ${issuerKeyPath}`);
    process.exit(1);
  }
  const issuerKey = readFileSync(issuerKeyPath, "utf8").trim();
  const issuer = new ethers.Wallet(issuerKey, provider);
  const issuerBal = await provider.getBalance(issuer.address);
  console.log(`Distribution issuer: ${issuer.address} (balance: ${issuerBal})`);

  // Load validator account wallets from volume1
  const { readdirSync } = await import("fs");
  const validatorDirs = readdirSync(vol1).filter(d => d.startsWith("besu-v-")).sort();
  const wallets = [];
  for (const dir of validatorDirs) {
    const keyPath = resolve(vol1, dir, "account/privatekey");
    if (!existsSync(keyPath)) {
      console.error(`Validator key not found: ${keyPath}`);
      process.exit(1);
    }
    const key = readFileSync(keyPath, "utf8").trim();
    wallets.push(new ethers.Wallet(key, provider));
  }
  console.log(`Loaded ${wallets.length} validator account wallets`);

  // Gas overrides — use low legacy gasPrice to avoid EIP-1559 fee estimation issues
  const txOpts = { gasPrice: 100n, gasLimit: 200000n };

  // Step 1: Fund validator accounts
  const fundAmount = 1000000000n; // 10^9 wei — enough for many txs at gasPrice=100
  console.log(`\nFunding validator accounts with ${fundAmount} wei each...`);
  for (let i = 0; i < wallets.length; i++) {
    const bal = await provider.getBalance(wallets[i].address);
    if (bal < fundAmount) {
      const tx = await issuer.sendTransaction({ to: wallets[i].address, value: fundAmount, ...txOpts });
      await tx.wait();
      console.log(`  Funded ${validatorDirs[i]}: ${wallets[i].address.slice(0,10)}...`);
    } else {
      console.log(`  ${validatorDirs[i]} already funded: ${bal}`);
    }
  }

  // Step 2: Read current state
  const dao = new ethers.Contract(daoAddress, ABI, provider);
  const validators = await dao.getValidators();
  console.log(`\nCurrent validators: ${validators.length}`);

  const numAllowed = await dao.numAllowedAccounts();
  console.log(`Allowed accounts: ${numAllowed}`);
  const requiredVotes = Math.floor(Number(numAllowed) / 2) + 1;
  console.log(`Required votes for majority: ${requiredVotes}`);

  // Step 3: Vote to add a random test account
  const testWallet = ethers.Wallet.createRandom();
  console.log(`\nTest account: ${testWallet.address}`);
  console.log(`Voting to ADD (need ${requiredVotes} votes)...`);

  for (let i = 0; i < requiredVotes; i++) {
    const daoSigner = new ethers.Contract(daoAddress, ABI, wallets[i]);
    const tx = await daoSigner.voteToAddAccountToAllowList(testWallet.address, txOpts);
    const receipt = await tx.wait();
    console.log(`  Vote ${i+1}/${requiredVotes} from ${validatorDirs[i]} — block ${receipt.blockNumber}`);
  }

  // Step 4: Count votes (triggers the add)
  console.log(`Counting votes...`);
  const daoSigner0 = new ethers.Contract(daoAddress, ABI, wallets[0]);
  const txCount = await daoSigner0.countVotes(testWallet.address, txOpts);
  await txCount.wait();

  const newNumAllowed = await dao.numAllowedAccounts();
  const added = Number(newNumAllowed) === Number(numAllowed) + 1;
  console.log(`Allowed accounts after vote-in: ${newNumAllowed} — ${added ? "PASS" : "FAIL"}`);
  if (!added) process.exit(1);

  // Step 5: Vote to remove the test account
  const removeVotes = Math.floor(Number(newNumAllowed) / 2) + 1;
  console.log(`\nVoting to REMOVE (need ${removeVotes} votes)...`);

  for (let i = 0; i < removeVotes; i++) {
    const daoSigner = new ethers.Contract(daoAddress, ABI, wallets[i]);
    const tx = await daoSigner.voteToRemoveAccountFromAllowList(testWallet.address, txOpts);
    const receipt = await tx.wait();
    console.log(`  Vote ${i+1}/${removeVotes} from ${validatorDirs[i]} — block ${receipt.blockNumber}`);
  }

  // Step 6: Count removal votes
  console.log(`Counting removal votes...`);
  const txRemove = await daoSigner0.countVotes(testWallet.address, txOpts);
  await txRemove.wait();

  const finalNumAllowed = await dao.numAllowedAccounts();
  const removed = Number(finalNumAllowed) === Number(numAllowed);
  console.log(`Allowed accounts after vote-out: ${finalNumAllowed} — ${removed ? "PASS" : "FAIL"}`);

  // Step 7: Verify validators unchanged
  const finalValidators = await dao.getValidators();
  const unchanged = finalValidators.length === validators.length;
  console.log(`\nFinal validators: ${finalValidators.length}/${validators.length} — ${unchanged ? "PASS" : "FAIL"}`);

  const allPass = added && removed && unchanged;
  console.log(`\n=== DAO VOTING TEST: ${allPass ? "PASSED" : "FAILED"} ===`);
  process.exit(allPass ? 0 : 1);
}

main().catch(e => { console.error("Fatal:", e.message); process.exit(1); });
