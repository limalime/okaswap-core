import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with address:", deployer.address);

  const dexRouter = process.env.DEX_ROUTER || "0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3";
  const zkVerify = process.env.ZKVERIFY_ADDRESS || "0xEA0A0f1EfB1088F4ff0Def03741Cb2C64F89361E";
  const vkeyHash = process.env.VK_HASH || "0x1d137ad8b1b992e8d8c472b7a26e7d76c2b20fa1d7ffaab9c351e41d9cf6e42d";
  const provingSystem = process.env.PROVING_SYSTEM || "groth16";
  const proverVersion = process.env.PROVER_VERSION || "circom:1.0.0";
  const name = "Okswap";
  const version = "1";

  if (!dexRouter || !zkVerify || !vkeyHash) {
    throw new Error("Please set DEX_ROUTER, ZKVERIFY_ADDRESS and VK_HASH in your environment");
  }

  // Deploy Router with placeholder relayer address (will be updated after deploying Relayer)
  const Router = await ethers.getContractFactory("Router");
  const router = await Router.deploy(dexRouter, "0x0000000000000000000000000000000000000001");
  await router.deployed();
  console.log("Router deployed at:", router.address);

  // Deploy ProofVerifier with zkVerify configuration
  const ProofVerifier = await ethers.getContractFactory("ProofVerifier");
  const proofVerifier = await ProofVerifier.deploy(
    zkVerify,
    vkeyHash,
    provingSystem,
    proverVersion
  );
  await proofVerifier.deployed();
  console.log("ProofVerifier deployed at:", proofVerifier.address);

  // Deploy Relayer with router and verifier addresses and EIP712 domain details
  const Relayer = await ethers.getContractFactory("Relayer");
  const relayer = await Relayer.deploy(router.address, proofVerifier.address, name, version);
  await relayer.deployed();
  console.log("Relayer deployed at:", relayer.address);

  // Configure router to use the newly deployed relayer
  const tx = await router.setRelayer(relayer.address);
  await tx.wait();
  console.log("Router relayer set to:", relayer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
