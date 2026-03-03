import { ethers } from "ethers";
import { readFileSync } from "fs";

const RPC_URL = process.env.RPC_URL;
const CHAIN_ID = parseInt(process.env.CHAIN_ID, 10);
const ISSUER_KEY_PATH = process.env.ISSUER_KEY_PATH;
const RECIPIENT_KEY_PATH = process.env.RECIPIENT_KEY_PATH;
const DISTRIBUTION_CONTRACT = "0x8Be503bcdEd90ED42Eff31f56199399B2b0154CA";

const DIST_ABI = [
  "function distribute(address[] recipients, uint256[] amounts)",
  "function issuer() view returns (address)",
  "event Distributed(address indexed recipient, uint256 amount)"
];

let failures = 0;

function check(label, condition) {
  if (condition) {
    console.log(`  PASS: ${label}`);
  } else {
    console.log(`  FAIL: ${label}`);
    failures++;
  }
}

async function main() {
  if (!RPC_URL || !CHAIN_ID || !ISSUER_KEY_PATH || !RECIPIENT_KEY_PATH) {
    console.error("Missing required env vars: RPC_URL, CHAIN_ID, ISSUER_KEY_PATH, RECIPIENT_KEY_PATH");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL, CHAIN_ID);

  // Read issuer private key
  const issuerKey = readFileSync(ISSUER_KEY_PATH, "utf8").trim();
  const issuerWallet = new ethers.Wallet(issuerKey, provider);
  console.log("Issuer address:", issuerWallet.address);

  // Derive recipient address from validator 1 account key
  const recipientKey = readFileSync(RECIPIENT_KEY_PATH, "utf8").trim();
  const recipientAddr = new ethers.Wallet(recipientKey).address;
  console.log("Recipient (validator 1 account):", recipientAddr);

  // Connect to Distribution contract
  const dist = new ethers.Contract(DISTRIBUTION_CONTRACT, DIST_ABI, issuerWallet);

  // 1. Verify on-chain issuer matches wallet
  const onChainIssuer = await dist.issuer();
  console.log("\n--- Issuer verification ---");
  console.log("On-chain issuer:", onChainIssuer);
  check("Issuer matches wallet", onChainIssuer.toLowerCase() === issuerWallet.address.toLowerCase());

  // 2. Get recipient balance before
  const balBefore = await provider.getBalance(recipientAddr);
  console.log("\n--- Distribution call ---");
  console.log("Recipient balance before:", balBefore.toString());

  // 3. Call distribute with 1000 wei
  const amount = 1000n;
  console.log(`Calling distribute([${recipientAddr}], [${amount}])...`);

  const tx = await dist.distribute(
    [recipientAddr],
    [amount],
    { gasPrice: 100n, gasLimit: 200000n }
  );
  console.log("TX hash:", tx.hash);

  const receipt = await tx.wait();
  console.log("Block:", receipt.blockNumber);
  console.log("Gas used:", receipt.gasUsed.toString());

  // 4. Check tx status
  check("TX status is SUCCESS", receipt.status === 1);

  // 5. Check Distributed event
  console.log("\n--- Event verification ---");
  const events = receipt.logs
    .map(log => {
      try { return dist.interface.parseLog(log); } catch { return null; }
    })
    .filter(e => e && e.name === "Distributed");

  check("Distributed event emitted", events.length > 0);
  if (events.length > 0) {
    for (const ev of events) {
      console.log(`  Event: recipient=${ev.args.recipient}, amount=${ev.args.amount}`);
    }
  }

  // 6. Verify balance increase
  console.log("\n--- Balance verification ---");
  const balAfter = await provider.getBalance(recipientAddr);
  console.log("Recipient balance after:", balAfter.toString());
  const diff = balAfter - balBefore;
  console.log("Balance increase:", diff.toString());
  check("Balance increased by expected amount", diff === amount);

  // Summary
  console.log("\n===========================");
  if (failures === 0) {
    console.log("Distribution test PASSED");
  } else {
    console.log(`Distribution test FAILED (${failures} check(s) failed)`);
  }
  console.log("===========================");

  process.exit(failures > 0 ? 1 : 0);
}

main().catch(err => {
  console.error("ERROR:", err.message || err);
  process.exit(1);
});
