import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()

  await deployments.deploy('MultiSigWalletFactory', {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
}

deploy.tags = ['MultiSigWalletFactory']
export default deploy