import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()

  await deployments.deploy('MultiSigWallet', {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
}

deploy.tags = ['MultiSigWallet']
export default deploy