import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre
  const { deployer, account2, account3 } = await getNamedAccounts()

  // await deployments.deploy('MultiSigWalletV2', {
  //   from: deployer,
  //   args: [
  //     [deployer, account2, account3],
  //     2
  //   ],
  //   log: true,
  //   deterministicDeployment: false
  // })
}

deploy.tags = ['MultiSigWalletFlex']
export default deploy