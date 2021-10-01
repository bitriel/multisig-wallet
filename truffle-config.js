const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {
  networks: {
    mainnet: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 1,
    },
    ropsten: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 3,
    },
    rinkeby: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 4,
    },
    kovan: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 42,
    },
    // bsc
    bsc: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://bsc-dataseed.binance.org`),
      network_id: 56,
    },
    testnet: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      timeoutBlocks: 200,
    },
    // selendra
    selendraTestnet: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://rpc.testnet.selendra.org/`),
      network_id: 2000,
    },
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
    },
  },

  compilers: {
    solc: {
      version: "0.7.6",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 100
        },
      }
    }
  },

  db: {
    enabled: false
  },
  
  plugins: [
    'truffle-plugin-verify',
    'truffle-contract-size'
  ],

  api_keys: {
    bscscan: process.env.BSC_API_KEY,
    etherscan: process.env.ETH_API_KEY
  }
};
