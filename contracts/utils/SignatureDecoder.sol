// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "../libraries/FullMath.sol";

abstract contract SignatureDecoder {
  function signatureSplit(bytes memory signatures, uint256 pos)
    internal
    pure
    returns (
      uint8 v,
      bytes32 r,
      bytes32 s
    )
  {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let signaturePos := mul(0x41, pos)
      r := mload(add(signatures, add(signaturePos, 0x20)))
      s := mload(add(signatures, add(signaturePos, 0x40)))
      // Here we are loading the last 32 bytes, including 31 bytes
      // of 's'. There is no 'mload8' to do this.
      //
      // 'byte' is not working due to the Solidity parser, so lets
      // use the second best option, 'and'
      v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
    }
  }
}