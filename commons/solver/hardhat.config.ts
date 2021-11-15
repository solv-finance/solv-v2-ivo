import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

import { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-tracer";
import "hardhat-contract-sizer";
import "@solv/v2-hardhat-plugins/ozUpgrade";
import "@solv/v2-hardhat-plugins/gasNowPrice";

import "solidity-coverage";

const DEPLOYER_PRIVATE_KEY =
  process.env.RINKEBY_PRIVATE_KEY! ||
  "0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {},
    localhost: {},
    development: {
      url: `http://47.88.20.217:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    testnet: {
      url: `http://47.88.20.217:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    labs: {
      url: `http://47.88.20.217:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    mainnet: {
      url: `http://172.21.121.12:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    bsctest: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
      live: true,
      saveDeployments: true,
    },
    bscstage: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [DEPLOYER_PRIVATE_KEY],
      live: true,
      saveDeployments: true,
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [DEPLOYER_PRIVATE_KEY],
      live: true,
      saveDeployments: true,
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    polygon: {
      url: "https://rpc-mainnet.maticvigil.com",
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
    },
  },
  mocha: {
    timeout: 2000000,
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  external: process.env.HARDHAT_FORK
    ? {
        deployments: {
          // process.env.HARDHAT_FORK will specify the network that the fork is made from.
          // these lines allow it to fetch the deployments from the network being forked from both for node and deploy task
          hardhat: ["deployments/" + process.env.HARDHAT_FORK],
          localhost: ["deployments/" + process.env.HARDHAT_FORK],
        },
      }
    : undefined,
};

export default config;
