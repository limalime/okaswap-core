import { task } from "hardhat/config";

// Prints the list of accounts available via Hardhat
task("accounts", "Prints the list of deployer accounts").setAction(async (_, hre) => {
  const accounts = await hre.ethers.getSigners();
  accounts.forEach((account) => {
    console.log(account.address);
  });
});