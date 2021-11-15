import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

import { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-etherscan";

import "solidity-coverage";

const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY! ||
  "0000000000000000000000000000000000000000000000000000000000000000"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ''

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{
      version: "0.7.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000
        }
      }
    }],
  },
  networks: {
    hardhat: {
    },
    localhost: {
    },
    development: {
      url: `http://123.57.44.197:18241`,
      accounts: [RINKEBY_PRIVATE_KEY],
    },
    rinkeby: {
      url: `http://123.57.44.197:18241`,
      accounts: [RINKEBY_PRIVATE_KEY],
    },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 2000000
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY,
  },
};

export default config;
