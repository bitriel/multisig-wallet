// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

library FullMath {
  /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
        return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "multiply overflow");

    return c;
  }

  /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "subtract overflow");
    uint256 c = a - b;

    return c;
  }

  /**
    * @dev Adds two numbers, reverts on overflow.
    */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "add overflow");

    return c;
  }

  /**
    * @dev Returns the largest of two numbers.
    */
  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  /**
    * @dev Returns the smallest of two numbers.
    */
  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}