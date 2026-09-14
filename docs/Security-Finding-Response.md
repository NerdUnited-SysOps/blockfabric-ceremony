# Response to the Rally / R-Link review of the ceremony scripts

**Repo reviewed:** `NerdUnited-SysOps/blockfabric-ceremony` at commit `2829381`
**Source of findings:** `R-Link-LLC/rally-ceremony`, `docs/FIXES.md` — 35 findings (4 Critical, 12 High, 19 Medium)
**Responding team:** Chain / Security team, Node Governance / Blockfabric
**Date:** 2026-09-14

In September 2026 the Rally development team (R-Link) forked this repository, audited it, and published a ledger of 35 findings with fixes in their fork. This document is Nerd United's response to each of those findings, one row per item, using their IDs.

Some of the items are correct and will be fixed. Most are rated as security findings only because the review was done without visibility into how the ceremony is actually run. Those operating controls are the primary security boundary, and they are described first so the dispositions make sense.

---

## 1. Findings versus changes

This document accepts or rejects **findings**. It does not adopt any **code** from the `rally-ceremony` fork. The distinction matters, so it is spelled out here before anything else.

Accepting a finding means we agree the defect exists and Nerd United will fix it in this repository, on Nerd's schedule, written and reviewed by Nerd's engineers, and tested against the private ceremony tooling and the ceremony image on real hardware before any release.

Accepting a change would mean pulling commits from the fork into this repository. We are not doing that, for three reasons that have nothing to do with whether the fork's fixes are good:

**The fork is not a patch set; it is a different repository.** It removed the bridge and multisig tooling, added a full Besu sandbox, added its own Solidity contracts (`LockupAuto`, `LockupLegacy`, a `Distribution` with a changed constructor), rewrote the bootstrap flow to point at the sandbox, and reorganized shared helpers. Each fix is entangled with those changes. There is no clean cherry-pick.

**The fork's fixes were verified against a reconstruction.** They were reviewed by an automated reviewer and tested on a sandbox chain against contracts rebuilt from a runbook. None of it has run against the real ceremony additions, the real contracts, or the ceremony image on the ceremony laptop. Merging code into the repository that runs on that laptop on that basis is not acceptable.

**Provenance is a security property of this repository.** Every line in it should be traceable to a Nerd engineer who understands why it's there, because someone has to stand in a room and run it with real keys. An external commit that changes how secrets are persisted (C-03, C-04) or how host keys are verified (H-06) needs to be written and understood by the people running it.

The fork's `FIXES.md` is therefore treated as a bug report. Accepted items will be opened as issues in this repository, referenced by finding ID, and fixed in-house. Where a fix is small and self-contained we may borrow the approach; the code will still be authored here. Pull requests from the fork against `main` will not be accepted. Please file issues instead.

---

## 2. The ceremony threat model

The scripts in this repository are never run on a general-purpose machine. Every finding below has to be read against the following controls, which are part of the ceremony and not optional:

**Hardware.** The ceremony runs on a dedicated laptop with no internal storage and the WiFi radio disabled at first boot. The operating system is a read-only live image (`kali-live`, no persistence partition) booted from USB. Nothing survives shutdown. The filesystem is destroyed at the end of the ceremony by design.

**Custody volumes.** Secrets are written to FIPS 140-2 Level 3 hardware-encrypted devices, one per custodian (Trust, Node Governance, Brand, Blockade). Each device is PIN-protected with brute-force auto-wipe. A custodian holding one volume cannot reconstruct anything alone.

**People and process.** Two operators are present (primary signing, secondary verifying). Every ceremony, rehearsal or production, is video recorded. Chain-of-custody forms are signed. An auditor records deviations.

**No AI, no telemetry.** No AI assistant, agent, or cloud-connected tooling runs on the ceremony machine. Keys are handled only on the air-gapped device. This is deliberate: an AI-assisted operator workstation logs keystrokes, screen content, and file contents to third-party services, which is a larger exposure than any item in this list.

Findings that describe a key existing "in plaintext" on the ceremony laptop, or on a custody volume, are therefore describing a key inside two layers of control (destroyed-on-shutdown OS, FIPS-encrypted volume) that the review did not model.

---

## 3. Reviewer responses

The Chain / Security team that built and runs this ceremony reviewed all 35 items in R-Link's `FIXES.md`. Two of the team's overall responses are recorded here because they frame every disposition that follows.

**Ceremony operator:**

> The ceremony runs on an air-gapped, sterile machine with no internal storage. That is the point of it. Every key we handle is handled on that device and nowhere else, and the device is wiped when we're done. The findings rated "critical" describe keys on that machine, or on hardware-encrypted custody devices, as if they were sitting on a workstation. They aren't.
>
> The one item that actually matters is the issuer funding key in Secrets Manager. Not because it's stored the way it's stored — access is restricted and logged — but because it is a single key with authority over the entire distribution system. That's the real concentration of risk, and the review understates it. Encrypting it at rest or sharding it is a custody decision we'll take, and it comes with the tradeoff that recovery becomes a multi-party event.
>
> Beyond that, the ceremony's security comes from the fact that nothing connected, nothing logging, and nothing AI-assisted ever touches the keys. Changes to the shell scripts don't make the process more or less secure; the operating environment does. Anyone proposing to run this from a general-purpose machine with AI tooling on it is proposing a larger exposure than any finding on this list.

**Ceremony designer:**

> None of the findings are surprising. This ceremony was designed four years ago in a very different landscape, and it prioritized transparency and auditability above everything else — every step visible, every artifact recorded, every custodian able to verify. Should some of it be done differently today? Maybe. Can it be improved? Absolutely. But the findings should be read as improvements to a process whose security model was and is the air gap, the custody hardware, and the people in the room, not the scripts.

The dispositions below follow from that framing: code-level defects are accepted and will be fixed; items that only rate as security findings if you ignore the operating controls are accepted at reduced severity or rejected.

---

## 3a. On automated review and tradeoffs

Most of the findings in `FIXES.md`, and all of the fixes in the fork, were produced or reviewed by an automated code reviewer. It has a predictable limitation that shows up throughout the list: an automated reviewer pointed at a repository will always find issues, because it evaluates code in isolation. It cannot see the controls that live outside the code, so it does not know which risks are already handled by the process and which are not. The result is fixes proposed for their own sake, each individually defensible, collectively adding surface area to a procedure whose safety depends on being small enough for two people to understand completely while running it with real keys.

One example from the fork's own review passes: a guard was added so the new Lockup reverts if the un-halved daily rate is zero, on the reasoning that a zero rate would deploy a vault that can never release. That is true. It is also a value that no operator would ever supply, and the runbook already requires every immutable constructor argument to be pre-filled and verified by a second engineer against the brand's genesis record at least 24 hours before the ceremony. The guard is not wrong. It replaces a human control the reviewer could not see with a code check the reviewer could write, and every such check is one more thing the operators have to read, understand, and account for in the room.

The same pattern explains most of the reduced-severity dispositions below. "Plaintext key on the custody volume" is Critical if the volume is a USB stick and Medium if it is a FIPS 140-2 Level 3 device with auto-wipe. "Same-day rerun overwrites the log" is High if the log is the audit record and Low if the audit record is a video recording and signed chain-of-custody forms. The reviewer rated against the code because the code was all it had. The dispositions rate against the ceremony.

This is why the response to a list of 35 is not 35 code changes, and why the ones that are made will be made by the people who run the ceremony.

---

## 4. Dispositions

Disposition key:

- **Accept** — the finding is valid as stated; Nerd United will fix it in this repository.
- **Accept (reduced)** — valid, but severity is lower under the ceremony's controls.
- **Mitigated** — the risk is addressed by an operating control the reviewer could not see; no code change planned.
- **Reject** — not a defect, or the proposed change would not improve security.
- **Out of scope** — belongs to a different system or team.

### 4.1 Critical

| ID | Finding | Disposition | Notes |
|----|---------|-------------|-------|
| C-01 | Plaintext `privatekey` written to every custodian volume | **Accept (reduced)** → Medium | Volumes are FIPS-encrypted and PIN-protected; the laptop's filesystem is destroyed. The plaintext copy is redundant to the keystore+password already on the volume and offers nothing once a volume is unlocked except a second copy to protect. We will stop writing it. Not Critical under the ceremony's controls. |
| C-02 | Validator node keys staged into the ansible checkout and pushed to the brand repository | **Accept** | Valid regardless of air gap. Anything committed to a git repository is in the history of every clone. Node keys will be written outside the ansible tree and persistence will push logs only. |
| C-03 | Issuer private key stored in Secrets Manager (`L2_FUNDING_PK`) | **Accept (reduced)** → High | Access to the secret is restricted to a small number of named principals with MFA, and access is logged. The larger concern, which the review understates, is that this is a single key with authority over the whole distribution flow. We will evaluate encrypting at rest with a separately held passphrase, or sharding, with the tradeoff that operational recovery becomes a multi-party event. Decision pending. |
| C-04 | Secret writes backgrounded with `&`; success reported regardless of outcome | **Accept** | Not a confidentiality issue but a correctness one: a ceremony could report "persisted" with nothing written. Writes will be synchronous and verified by read-back before success is reported. |

### 4.2 High

| ID | Finding | Disposition | Notes |
|----|---------|-------------|-------|
| H-01 | `chain_repo_tag` reverted 2.3.2 → 2.1.1 by PR #81 | **Accept** | Pin will be corrected and the version asserted at bootstrap. |
| H-02 | Ceil rounding in `current_unlocked` on Besu overstates by a day | **Accept** | Validation-side only; does not affect chain state. Will fix. |
| H-03 | Immutable bytecode offsets hardcoded with no pre/post assertion | **Accept** | Genesis generator will assert the target bytes are the compiler placeholder and read the patched value back. |
| H-04 | README validation steps unreachable | **Accept (reduced)** → Low | Documentation drift. Will fix. |
| H-05 | `printer -e` neutered by pipe to `tee` | **Accept (reduced)** → Low | Error visibility, not security. Will fix. |
| H-06 | `StrictHostKeyChecking=no` / `ANSIBLE_HOST_KEY_CHECKING=False` | **Accept** | Validator host keys will be recorded before first connection and verified thereafter. |
| H-07 | Unpinned ceremony-time fetches (galaxy, `go mod tidy`, branch refs) | **Accept** | Ceremony-time network fetches should be pinned by digest or vendored. Related: the live image currently downloads Go modules during the ceremony; see Section 6. |
| H-08 | Force-push to a date-named branch; same-day rerun overwrites the earlier log | **Accept (reduced)** → Low | Not a security finding. The video recording and signed custody forms are the audit record of a failed run; the pushed log is secondary. We will still make branch names unique per run so a failed attempt's log is retained. |
| H-09 | Runbook recovery snippet uses bash integer arithmetic on wei amounts | **Accept** | Correct. Bash `$(( ))` is 64-bit signed; wei values exceed it for any realistic balance. Internal runbook will be corrected to use `cast` / `python3` for arithmetic. |
| H-10 | Admin slots equal to the number of required calls, none spare | **Accept** | Internal runbook change: grant spares and revoke unused slots at lockdown. |
| H-11 | End-state validation is read-only; no live `distribute()` | **Reject** | Read-only verification at the end of a production ceremony is a deliberate choice. Executing a live `distribute()` against a newly deployed contract holding the brand's full supply, from a ceremony wallet, in the same session, adds risk to prove something a rehearsal already proves. Live payout tests belong in the testnet rehearsal, not the production run. |
| H-12 | 365.25-day on-chain year vs calendar-date halving in the distribution CSV | **Accept (cross-team)** | The on-chain contract and the distribution pipeline must agree on the boundary. Will be resolved jointly with the distribution team. |

### 4.3 Medium

| ID | Finding | Disposition | Notes |
|----|---------|-------------|-------|
| M-01 | `$genesis` undefined; `scp` calls no-op | **Reject** | The ceremony image exports `genesis` in `.zshrc`. The reviewer later corrected this finding themselves. Scripts worked on the real laptop. |
| M-02 | `if ! scp \| tee` tests `tee`'s status | **Accept** | Will fix. |
| M-03 | `$?` checks unreachable under `set -e` | **Accept** | Will fix. |
| M-04 | Guards `ANSIBLE_CEREMONY_DIR`, uses `ANSIBLE_DIR` | **Accept** | Will fix. |
| M-05 | `pwgen` without `-s` | **Accept** | Will use `-s`. Passwords are stored on FIPS volumes, so exposure is limited, but there is no reason not to. |
| M-06 | `volume_prompt` accepts any input | **Accept (reduced)** → Low | Two-operator process catches this; will add validation anyway. |
| M-07 | `-o` numbering diverges from menu; Exit returns 1 | **Accept (reduced)** → Low | Usability. Will fix. |
| M-08 | `-r` unreachable, `reset.sh` missing, dead functions | **Accept (reduced)** → Low | Cleanup. Will fix. |
| M-09 | `bridge.sh` option/printer bugs | **Accept (reduced)** → Low | Bridge tooling is on a separate track. Will fix there. |
| M-10 | PAT interpolated into `sed` unescaped | **Accept** | Will escape or avoid `sed` for this. |
| M-11 | Log message names wrong key file | **Accept (reduced)** → Low | Cosmetic. Will fix. |
| M-12 | Contract addresses hardcoded in 3 files; optstring bugs | **Accept** | Will centralize. |
| M-13 | DAO storage via `tail`/`head` line slicing | **Accept** | Will replace with a structured parse. |
| M-14 | `persistence.sh` has no menu; README documents one | **Accept (reduced)** → Low | Documentation drift. Will fix. |
| M-15 | 207 recovery is manual SQL | **Out of scope** | Distribution pipeline. Forwarded to the distribution team. |
| M-16 | Divide-by-zero remedy is "Mark Success" | **Out of scope** | Distribution pipeline. Forwarded. |
| M-17 | Anti-fraud variance check clearable by one person | **Out of scope** | Distribution pipeline. Forwarded. |
| M-18 | Batch size / buffer inconsistencies in the guide | **Out of scope** | Documentation for the distribution pipeline. Forwarded. |
| M-19 | MST vs UTC ambiguity in the guide | **Out of scope** | Documentation for the distribution pipeline. Forwarded. |

---

## 5. Additional point raised in the reviewer's notes

**"Lockdown is not permanent — the OLD Lockup owner can re-grant admins."** Correct. The owner key is not burned by the migration and `setAdmins` is a repeatable owner function. The runbook's wording ("permanently inert") will be corrected to "paused, empty, no active admins; owner retains the ability to re-enable." Whether the owner key should be rotated to a dead address after migration is a governance decision, not a script change.

---

## 6. Findings against the ceremony image, raised separately

The reviewer booted the public `ceremony_v1.3.1.iso` and reported two items that belong to the image maintainers, not this repo:

- `/home/user/go` is owned by root, so Go tooling fails when run as `user`.
- No Go module cache ships on the image, so genesis helpers download go-ethereum from the public proxy during the ceremony. This is the one place the ceremony laptop needs outbound internet mid-ceremony. Vendoring the modules into the image removes that dependency.

Both are forwarded.

---

## 7. What the R-Link review does and does not establish

R-Link's rehearsals were performed against contracts they reconstructed from the migration runbook, on their own sandbox chain, not against the brand's deployed contracts or a Foundry United testnet, and not from the ceremony hardware. Their review establishes that the public scripts at `2829381` have the defects listed above. It does not establish anything about the deployed contracts, and it is not a substitute for the recorded testnet rehearsal on ceremony hardware that gates any production ceremony. R-Link's own `rally-foundations` README says the same.

A note on method: automated review of an unfamiliar codebase produces findings efficiently, but severity has to be assigned against the system's actual controls. Roughly a third of the items above are correct as code observations and mis-rated as security findings because the reviewer could not see the air gap, the FIPS custody, the destroyed filesystem, or the two-operator recorded process. We ask that future reviews from the Rally team be scoped with those controls in hand; we will provide the ceremony procedure document to make that possible.

---

## Summary

| Disposition | Count |
|---|---|
| Accept | 17 |
| Accept (reduced severity) | 11 |
| Reject | 2 |
| Out of scope (distribution pipeline) | 5 |
| **Total** | **35** |

Accepted items will be tracked in this repository's issues, referenced by finding ID, and fixed by Nerd United. No code is merged from the `rally-ceremony` fork.
