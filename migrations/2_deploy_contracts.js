const MultiSigWallet = artifacts.require('MultiSigWallet.sol')
const MultiSigWalletFactory = artifacts.require('MultiSigWalletFactory.sol')

module.exports = async (deployer, _network, accounts) => {
  await deployer.deploy(MultiSigWalletFactory)
  const factory = await MultiSigWalletFactory.deployed();
  console.log(`========== MultiSignature Wallet Factory deployed: ${factory.address} ==========`)

  await deployer.deploy(MultiSigWallet, [accounts[0], accounts[1], accounts[2]], 2)
  const multisig = await MultiSigWallet.deployed();
  console.log(`========== MultiSignature Wallet deployed: ${multisig.address} ==========`)
}
