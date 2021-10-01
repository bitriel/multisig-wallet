const MultiSigWallet = artifacts.require('MultiSigWallet.sol')
const MultiSigWalletFactory = artifacts.require('MultiSigWalletFactory.sol')

module.exports = async (deployer, network, accounts) => {
  const args = process.argv.slice()
  if (args.length == 0) {
    deployer.deploy(MultiSigWalletFactory)
    console.log("========== MultiSignature Wallet Factory deployed ==========")
  } else if (args.length < 5) {
    console.error("Multisig with daily limit requires to pass owner " +
      "list, required confirmations and daily limit")
  } else if (args.length < 6) {
    deployer.deploy(MultisigWalletWithoutDailyLimit, args[3].split(","), args[4])
    console.log("Wallet deployed")
  } else {
    deployer.deploy(MultisigWalletWithDailyLimit, args[3].split(","), args[4], args[5])
    console.log("Wallet with Daily Limit deployed")
  }
}
