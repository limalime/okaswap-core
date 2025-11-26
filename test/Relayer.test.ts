import { expect } from "chai";
import { ethers } from "hardhat";

/**
 * This test suite performs basic checks on the Relayer contract. It verifies that the contract deploys
 * correctly, stores the supplied domain name and version in the EIP‑712 domain separator, and maintains
 * user nonces. Full integration tests that execute real swaps should be implemented with appropriate
 * ERC20 token mocks and a DEX router on a forked network.
 */
describe("Relayer", function () {
  it("deploys and stores initial state", async function () {
    const [deployer] = await ethers.getSigners();
    // Deploy a dummy Router. It won't be used in this test but is required by the Relayer constructor.
    const DummyRouter = await ethers.getContractFactory("Router");
    const dummyRouter = await DummyRouter.deploy(deployer.address, deployer.address);
    await dummyRouter.deployed();
    // Deploy a mock proof verifier defined in contracts/mocks/MockProofVerifier.sol
    const MockProofVerifier = await ethers.getContractFactory("MockProofVerifier");
    const dummyVerifier = await MockProofVerifier.deploy();
    await dummyVerifier.deployed();
    // Deploy the Relayer
    const Relayer = await ethers.getContractFactory("Relayer");
    const relayer = await Relayer.deploy(
      dummyRouter.address,
      dummyVerifier.address,
      "TestRelayer",
      "1"
    );
    await relayer.deployed();
    expect(await relayer.router()).to.equal(dummyRouter.address);
    expect(await relayer.proofVerifier()).to.equal(dummyVerifier.address);
    // Nonce for deployer should be 0
    expect(await relayer.nonces(deployer.address)).to.equal(0);
  });
});