// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

abstract contract SelfAuthorized {
  function _selfCall() private view {
    require(msg.sender == address(this), "required self call");
  }

  modifier authorized() {
    _selfCall();
    _;
  }
}