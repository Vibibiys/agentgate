# AgentGate — an Agent-ID-Gated Registry

AgentGate is an open registry on BSC that only **Agent ID** holders can join, plus a
one-call verification gate that any other project can compose with to run agent-only
mints and actions.

An address registers once. Registration is possible only while the address holds an
Agent ID, and AgentGate re-checks ownership on every later interaction — so the
registry always reflects *current* Agent ID holders, not just whoever held one once.
Registered agents can check in once per UTC day, building a public on-chain activity
record tied to their Agent ID.

## How Agent ID is integrated (core, not decoration)

Agent ID is an ERC-721 issued by SPACE ID on BSC mainnet:
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`. An address "holds an Agent ID" iff
`balanceOf(address) > 0` on that contract. AgentGate builds its entire access model
on that read:

- **Access control at the door** — `register()` reverts unless
  `AGENT_ID.balanceOf(msg.sender) > 0` at the moment of registration.
- **Continuous verification** — `checkIn()` re-checks ownership on every call. An
  address that no longer holds an Agent ID can no longer check in, and immediately
  stops passing the gate below.
- **The composable gate** — `isVerifiedAgent(address)` returns `true` only for an
  address that is registered **and** still holds an Agent ID right now. This is the
  function other projects call as their allowlist:

  ```solidity
  interface IAgentGate {
      function isVerifiedAgent(address agent) external view returns (bool);
  }

  // Inside your mint / action:
  require(agentGate.isVerifiedAgent(msg.sender), "Verified Agent ID holders only");
  ```

  One integration gives a project a live, self-maintaining allowlist of verified
  Agent ID holders — no snapshots, no manual list updates, no merkle trees to rebuild
  when an Agent ID changes hands.

## Contract surface (`contracts/AgentGate.sol`)

| Function | Type | Behaviour |
|---|---|---|
| `register()` | write | Agent-ID holders only; one registration per address; stores timestamp + running index; emits `Registered(agent, index, timestamp)` |
| `checkIn()` | write | Registered + still-holding only; once per UTC day per address; bumps per-agent and global counters; emits `CheckedIn(agent, day, totalCheckIns)` |
| `isRegistered(address)` | view | Has this address ever registered? |
| `isVerifiedAgent(address)` | view | **The gate:** registered AND currently holds an Agent ID |
| `totalAgents()` | view | Number of registered agents |
| `totalCheckIns()` | view | Global check-in count |
| `checkInsOf(address)` | view | One agent's check-in count |
| `registeredAt(address)` | view | Registration timestamp (0 if unregistered) |
| `indexOf(address)` | view | Running index assigned at registration |

### Safety model

- **Moves no assets.** No payable functions, no transfers, no token approvals —
  the ABI contains zero `payable` entries (verifiable in `artifacts/`).
- **No admin.** The deployer is recorded in `owner` for transparency only; no
  function reads it. There is no pause, edit, removal, or upgrade path.
- **No oracles, no dependencies.** The only external call is a `balanceOf` view
  read of the official Agent ID contract.

## Demo site (`site/index.html`)

A single static page (no build step, no backend):

- Standard injected-wallet connect (EIP-1193) only — the user's own wallet, the
  user's own confirmation for every transaction.
- Live reads over public BSC RPC endpoints (`bsc-dataseed1.bnbchain.org`,
  `bsc-rpc.publicnode.com`): Agent ID holding status, registration status, gate
  result, total registered agents, personal check-in count.
- Register / Check-In buttons send the transaction through the connected wallet.
- The AgentGate address is a `CONFIG` constant at the top of the script — set it
  after deployment (currently the zero-address placeholder, so the buttons stay
  disabled and the page shows a "not deployed yet" notice).

## Build

```bash
npm install
npm run compile   # solc-js → artifacts/AgentGate.json, .abi.json, .bytecode.txt
```

Compiled with solc **0.8.38** (optimizer: 200 runs). Runtime+creation bytecode:
**1,909 bytes**.

## Deploy + verify (checklist for the deploy step — not done in v1)

1. Deploy `AgentGate` to BSC mainnet (chain id 56) from the deployer wallet using
   the bytecode in `artifacts/` (e.g. via Remix, Hardhat, or Foundry — constructor
   takes no arguments).
2. Record the deployed address; set it as `AGENTGATE_ADDRESS` in `site/index.html`
   and in this README.
3. Verify the contract source:
   - **BscScan:** submit `contracts/AgentGate.sol`, compiler `v0.8.38`, optimizer
     enabled / 200 runs, MIT license.
   - **Sourcify:** upload the source + metadata, or verify via the standard JSON
     input produced from the same settings used in `scripts/compile.js`.
4. Sanity-check on BscScan: `AGENT_ID()` returns the official Agent ID contract,
   `totalAgents()` reads 0, and a test `register()` from an Agent-ID-holding
   address succeeds while one from a non-holding address reverts.
5. Host `site/` as a static page and link it from the submission.

## Hackathon red-line compliance

- ✅ Wallet connection is the standard injected-wallet (EIP-1193) flow only —
  **no** web QR-code / pairing-code wallet login, **no** server-side sessions.
- ✅ Users confirm every transaction in their own wallet; nothing bypasses
  confirmation, and the contract requests **no approvals** of any kind.
- ✅ No unauthorized transfers — the contract cannot move assets at all.
- ✅ Contract is open-source (MIT) with owner permissions documented above
  (there are none).
- ✅ Project name/branding contains no "Binance"/"BNB" branding ("AgentGate";
  "BSC" / "BNB Chain" appear only descriptively in body text).
- ✅ No credential collection, no promises of returns or income anywhere.
- ✅ Agent ID is **not** used to look up other people's wallets by name — the
  registry only ever records addresses that register *themselves*.

## What remains

- [ ] Deploy `AgentGate` to BSC mainnet
- [ ] Verify source on BscScan + Sourcify
- [ ] Set the deployed address in `site/index.html` CONFIG and host the demo page
- [ ] Submit the project for the Agent ID Hackathon (deadline **2026-12-09 08:00 UTC**)
- [ ] Drive **30+ Agent ID holders** to register (hackathon eligibility gate:
      product live + ≥30 Agent ID addresses interacted with the contract during
      the submission period)
- [ ] (Stretch) Publish a short integration guide + example mint contract that
      consumes `isVerifiedAgent()`
