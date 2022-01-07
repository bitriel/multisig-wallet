// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;
import "./Types.sol";
import "../base/Executor.sol";

contract SimulateTx is Executor {
  function simulate(
    Types.Operation operation,
    address to, 
    uint256 value,
    bytes memory data
  ) external returns(
    bool success,
    uint256 gasEstimated,
    bytes memory returnData
  ) {
    uint256 startGas = gasleft();
    success = execute(operation, to, value, data, gasleft());
    gasEstimated = startGas - gasleft();
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let ptr := mload(0x40)
      mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
      mstore(ptr, returndatasize())
      returndatacopy(add(ptr, 0x20), 0, returndatasize())
      returnData := ptr
    }
  }
}