import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const privateKey = process.env.PRIVATE_KEY as string | undefined;
const sepoliaRpc = process.env.SEPOLIA_RPC_URL as string | undefined;
const etherscanApi = process.env.ETHERSCAN_API as string | undefined;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true,
    }
  },
  networks: {
    hardhat: {
      gas: 4000000,
      gasPrice: 50000000000
    },
    sepolia: {
      url: sepoliaRpc || "https://1rpc.io/sepolia",
      chainId: 11155111,
      accounts: privateKey ? [privateKey] : [],
      gasPrice: "auto"
    }
  },
  etherscan: {
    apiKey: {
      'sepolia': etherscanApi
    },
    customChains: [
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=11155111",
          browserURL: "https://sepolia.etherscan.io/"
        }
      }
    ]
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};

export default config;
