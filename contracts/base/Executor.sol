// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../utils/Types.sol";

abstract contract Executor {
  function execute(
    Types.Operation operation,
    address target,
    uint256 value,
    bytes memory data,
    uint256 txGas
  ) internal returns (bool success) {
    if(operation == Types.Operation.Call) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        success := call(txGas, target, value, add(data, 0x20), mload(data), 0, 0)
      }
    } else {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        success :=delegatecall(txGas, target, add(data, 0x20), mload(data), 0, 0)
      }
    }
  }
}