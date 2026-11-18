// Compile contracts/AgentGate.sol with solc-js and write artifacts.
// Usage: npm install && npm run compile
const fs = require("fs");
const path = require("path");
const solc = require("solc");

const root = path.join(__dirname, "..");
const sourcePath = path.join(root, "contracts", "AgentGate.sol");
const source = fs.readFileSync(sourcePath, "utf8");

const input = {
  language: "Solidity",
  sources: { "AgentGate.sol": { content: source } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: {
      "*": {
        "*": ["abi", "evm.bytecode.object", "evm.methodIdentifiers"],
      },
    },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input)));

let hasError = false;
for (const entry of output.errors || []) {
  console.log(`${entry.severity}: ${entry.formattedMessage}`);
  if (entry.severity === "error") hasError = true;
}
if (hasError) process.exit(1);

const contract = output.contracts["AgentGate.sol"]["AgentGate"];
const bytecode = contract.evm.bytecode.object;

const artifactsDir = path.join(root, "artifacts");
fs.mkdirSync(artifactsDir, { recursive: true });

const artifact = {
  contractName: "AgentGate",
  sourceFile: "contracts/AgentGate.sol",
  compiler: { name: "solc", version: solc.version() },
  optimizer: { enabled: true, runs: 200 },
  abi: contract.abi,
  bytecode: "0x" + bytecode,
  methodIdentifiers: contract.evm.methodIdentifiers,
};
fs.writeFileSync(
  path.join(artifactsDir, "AgentGate.json"),
  JSON.stringify(artifact, null, 2)
);
fs.writeFileSync(
  path.join(artifactsDir, "AgentGate.abi.json"),
  JSON.stringify(contract.abi, null, 2)
);
fs.writeFileSync(path.join(artifactsDir, "AgentGate.bytecode.txt"), "0x" + bytecode + "\n");

console.log("Compiler:", solc.version());
console.log("Bytecode size (bytes):", bytecode.length / 2);
console.log("Method identifiers:", JSON.stringify(contract.evm.methodIdentifiers, null, 2));
console.log("Artifacts written to artifacts/");
