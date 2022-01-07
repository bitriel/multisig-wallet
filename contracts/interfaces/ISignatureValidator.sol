// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

contract ISignatureValidatorConstants {
  // bytes4(keccak256("isValidSignature(bytes,bytes)")
  bytes4 internal constant EIP1271_MAGIC_VALUE = 0x20c13b0b;
}

abstract contract ISignatureValidator is ISignatureValidatorConstants {
  function isValidSignature(bytes memory _data, bytes memory _signature) external view virtual returns (bytes4);
}