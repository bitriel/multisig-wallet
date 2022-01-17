// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

abstract contract TokensHandler is IERC165, IERC1155Receiver, IERC721Receiver, IERC777Recipient {
  function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return 0xf23a6e61;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
  ) external pure override returns (bytes4) {
    return 0xbc197c81;
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return 0x150b7a02;
  }

  // solhint-disable no-empty-blocks
  function tokensReceived(
    address,
    address,
    address,
    uint256,
    bytes calldata,
    bytes calldata
  ) external pure override {
    // We implement this for completeness, doesn't really have any value
  }

  function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
    return
      interfaceId == type(IERC1155Receiver).interfaceId ||
      interfaceId == type(IERC721Receiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }
}