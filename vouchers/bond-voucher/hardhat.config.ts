import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

import { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "@openzeppelin/hardhat-upgrades";

import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-tracer";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "solidity-coverage";

import "./deploy/helpers/deployBondPool";
import "./deploy/helpers/deployBondVoucher";
import "@solv/v2-hardhat-plugins/ozUpgrade";
import "@solv/v2-hardhat-plugins/factoryUpgrade";
import "@solv/v2-hardhat-plugins/gasNowPrice";
import "@solv/v2-hardhat-plugins/otherDeployments";

const DEPLOYER_PRIVATE_KEY =
  process.env.RINKEBY_PRIVATE_KEY! ||
  "0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "";
const INFURA_KEY = process.env.INFURA_KEY || "";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
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
      //url: `http://47.88.20.217:8545`,
      url: `https://rinkeby.infura.io/v3/${INFURA_KEY}`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    testnet: {
      url: `http://47.88.20.217:8545`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    bsctest: {
      url: `https://speedy-nodes-nyc.moralis.io/63fbfa7a2befc06f321c08fd/bsc/testnet`,
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
      url: "https://polygon-rpc.com/",
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    arbtest: {
      url: "https://rinkeby.arbitrum.io/rpc",
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    arb: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
    },
  },

  mocha: {
    timeout: 2000000,
  },

  gasReporter: {
    currency: "USD",
    gasPrice: 40,
  },

  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },

  typechain: {
    outDir: 'typechain'
  },

  external: process.env.HARDHAT_FORK
    ? {
        deployments: {
          hardhat: ["deployments/" + process.env.HARDHAT_FORK],
          localhost: ["deployments/" + process.env.HARDHAT_FORK],
        },
      }
    : undefined,
};

export default config;
