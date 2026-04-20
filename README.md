# 🗳 ConfidentialVote — Private DAO Governance on Zama fhEVM

> *The first DAO where vote tallies are mathematically impossible to see until the deadline.*

**Live Demo:** [labiletosky.github.io/confidential-vote](https://labiletosky.github.io/confidential-vote)  
**Network:** Ethereum Sepolia Testnet  
**Contract:** `0xYOUR_CONTRACT_ADDRESS`  
**Builder:** [@labiletosky](https://x.com/labiletosky)

---

## The Problem

Current DAO voting is broken. When votes are public in real time:
- Whales wait to see which way things are going before voting
- Voters get pressured or bribed based on live tallies
- Participation is skewed by bandwagon effects

**ConfidentialVote fixes this with Fully Homomorphic Encryption.**

---

## How It Works

```
User clicks "Vote YES" or "Vote NO"
        │
        ▼
fhevmjs encrypts the vote client-side (ZK proof generated)
        │
        ▼
Encrypted vote sent to smart contract on Sepolia
        │
        ▼
Contract adds encrypted vote to encrypted tally (FHE.or / FHE.add)
        │ ← Nobody can see the tally here. Not validators. Not you.
        ▼
Deadline passes → anyone calls requestResult()
        │
        ▼
Zama Gateway runs threshold MPC decryption
        │
        ▼
Result revealed on-chain → event emitted → UI updates
```

**Votes are encrypted using Zama's TFHE library. The chain computes on ciphertext, never plaintext.**

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| FHE Library | [Zama fhEVM](https://github.com/zama-ai/fhevm) (`@fhevm/solidity`) |
| Smart Contract | Solidity `^0.8.24` + `ZamaEthereumConfig` |
| Decryption | Zama Gateway (threshold MPC) |
| Client Encryption | [fhevmjs](https://www.npmjs.com/package/fhevmjs) v0.6 |
| Frontend | Vanilla HTML/CSS/JS — zero framework |
| Wallet | MetaMask + ethers.js v6 |
| Deployment | Remix IDE → Sepolia |
| Hosting | GitHub Pages |

---

## Smart Contract

**File:** `ConfidentialVote.sol`

### Key Functions

```solidity
// Create a proposal
function createProposal(string title, string description, uint256 durationSecs) 
  external returns (uint256 proposalId)

// Cast an FHE-encrypted vote
function castVote(uint256 proposalId, externalEbool encryptedVote, bytes inputProof) 
  external

// After deadline: trigger Gateway decryption
function requestResult(uint256 proposalId) external

// Gateway callback — receives decrypted result
function receiveResult(uint256 requestId, bool yesWon, bytes data) external onlyGateway
```

### FHE Types Used
- `ebool` — encrypted boolean (vote value, tally)
- `externalEbool` — encrypted user input from client
- `FHE.fromExternal()` — ZK proof verification + conversion
- `FHE.or()` — encrypted boolean accumulation
- `FHE.allow()` — ACL permission for Gateway decryption
- `Gateway.requestDecryption()` — async reveal after deadline

---

## Deploy on Remix IDE (Step by Step)

### 1. Open Remix
Go to [remix.ethereum.org](https://remix.ethereum.org)

### 2. Create the file
- New file → `ConfidentialVote.sol`
- Paste the contract code

### 3. Install fhEVM packages
In Remix terminal:
```bash
npm install @fhevm/solidity
```

Or use the Remix package manager plugin.

### 4. Compile
- Solidity compiler: `0.8.24`
- EVM version: `paris` or `shanghai`
- Enable optimization: ✅

### 5. Deploy to Sepolia
- Environment: **Injected Provider - MetaMask**
- Network: Sepolia (chain 11155111)
- Hit **Deploy**
- Copy your contract address

### 6. Update the frontend
In `index.html`, replace:
```js
const CONTRACT_ADDRESS = "YOUR_DEPLOYED_CONTRACT_ADDRESS";
```
with your real address.

---

## Run Locally

No build tools needed:

```bash
git clone https://github.com/labiletosky/confidential-vote
cd confidential-vote

# Option 1 — Python
python3 -m http.server 8080

# Option 2 — Node
npx serve .
```

Open `http://localhost:8080`

---

## Deploy Frontend to GitHub Pages

```bash
git init
git add .
git commit -m "launch: ConfidentialVote on Zama fhEVM"
git remote add origin https://github.com/labiletosky/confidential-vote.git
git push -u origin main
```

Then in GitHub repo → **Settings → Pages → Deploy from main branch root** ✓

---

## Why This Stands Out

Most fhEVM projects built so far are **payroll** apps (DripPay, BlindRoll).

ConfidentialVote targets **governance** — a bigger and more politically important use case:
- Bribery-resistant voting is a genuine unsolved problem in DAOs
- The "hidden tally" UX is immediately understandable to non-crypto users
- It demonstrates FHE's programmable access control (`FHE.allow`) cleanly
- Real-world parallel: exit polls in elections cause voters to bandwagon

---

## Video Pitch Script (3 minutes)

**[0:00–0:30] Hook**
> "Every DAO vote on Ethereum today is public. You can watch the tally change in real time. That's not voting — that's watching a leaderboard. ConfidentialVote fixes this."

**[0:30–1:15] Demo**
> Show creating a proposal → casting a YES vote → casting a NO vote → watching voterCount go up but no tally shown → deadline → clicking Reveal Result → result appears.

**[1:15–2:00] Technical**
> "When you vote, fhevmjs encrypts your choice client-side using Zama's TFHE library. The smart contract runs FHE operations directly on the ciphertext — it adds your encrypted vote to an encrypted tally. Nobody — not validators, not me, not you — can see the running count. After the deadline, anyone can call requestResult(), which triggers the Zama Gateway to run a threshold MPC decryption protocol. The result is revealed. That's it."

**[2:00–2:45] Impact**
> "This is the governance layer that every serious DAO will eventually need. Bribery attacks, voter suppression, bandwagon voting — all of these rely on knowing how others voted. With FHE, that information is mathematically unavailable until it's too late to exploit."

**[2:45–3:00] Close**
> "ConfidentialVote. Private votes. Trustless results. Built on Zama fhEVM."

---

## License

BSD-3-Clause-Clear — same as Zama's fhEVM library.

---

*Built for the Zama Developer Program Builder Track by [@labiletosky](https://x.com/labiletosky)*
