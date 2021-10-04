const MultiSigWallet = artifacts.require('MultiSigWallet.sol')
const MultiSigWalletFactory = artifacts.require('MultiSigWalletFactory.sol')

module.exports = async (deployer, network, accounts) => {
  const args = process.argv.slice()
  if (args.length == 0) {
    await deployer.deploy(MultiSigWalletFactory)
    const address = await MultiSigWalletFactory.deployed();
    console.log(`========== MultiSignature Wallet Factory deployed: ${address} ==========`)
  } else {
    await deployer.deploy(MultiSigWallet, accounts, 2)
    const address = await MultiSigWallet.deployed();
    console.log(`========== MultiSignature Wallet deployed: ${address} ==========`)
  }
}
