// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;
import "../utils/Types.sol";
import "../utils/SelfAuthorized.sol";

interface IGuard {
  function checkTransaction(
    Types.Operation operation,
    address to,
    uint256 value,
    bytes memory data,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver,
    bytes memory signatures,
    address from
  ) external;

  function checkAfterExecution(bytes32 txHash, bool success) external;
}

contract GuardManager is SelfAuthorized {
  event ChangedGuard(address guard);
  // keccak256("guard_manager.guard.address")
  bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

  function setGuard(address guard) public authorized {
    bytes32 slot = GUARD_STORAGE_SLOT;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, guard)
    }
    emit ChangedGuard(guard);
  }

  function getGuard() public view returns(address guard) {
    bytes32 slot = GUARD_STORAGE_SLOT;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      guard := sload(slot)
    }
  }
}