// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "./TokensHandler.sol";
import "../interfaces/ISignatureValidator.sol";
import "../MultiSigWalletV2.sol";

contract FallbackHandler is TokensHandler, ISignatureValidator {
  //keccak256(
  //    "SafeMessage(bytes message)"
  //);
  bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

  bytes4 internal constant SIMULATE_SELECTOR = bytes4(keccak256("simulate(address,bytes)"));

  address internal constant SENTINEL_MODULES = address(0x1);
  bytes4 internal constant UPDATED_MAGIC_VALUE = 0x1626ba7e;

  function isValidSignature(bytes calldata _data, bytes calldata _signature) public view override returns (bytes4) {
    MultiSigWalletV2 wallet = MultiSigWalletV2(payable(msg.sender));
    bytes32 messageHash = _getMessageHash(wallet, _data);
    if (_signature.length == 0) {
      require(wallet.signedMessages(messageHash) != 0, "Hash not approved");
    } else {
      wallet.checkSignatures(messageHash, _data, _signature);
    }
    return EIP1271_MAGIC_VALUE;
  }

  function getMessageHash(bytes memory message) public view returns (bytes32) {
    return _getMessageHash(MultiSigWalletV2(payable(msg.sender)), message);
  }

  function _getMessageHash(MultiSigWalletV2 wallet, bytes memory message) public view returns (bytes32) {
    bytes32 messageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
    return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), wallet.domainSeparator(), messageHash));
  }

  function isValidSignature(bytes32 _dataHash, bytes calldata _signature) external view returns (bytes4) {
    ISignatureValidator validator = ISignatureValidator(msg.sender);
    bytes4 value = validator.isValidSignature(abi.encode(_dataHash), _signature);
    return (value == EIP1271_MAGIC_VALUE) ? UPDATED_MAGIC_VALUE : bytes4(0);
  }
}