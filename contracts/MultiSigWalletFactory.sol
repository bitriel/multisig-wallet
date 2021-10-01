// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "./MultiSigWallet.sol";


/// @title Multi signature wallet factory - Allows creation of multisig wallet.
contract MultiSigWalletFactory {
    event WalletCreated(address creator, address wallet);

    mapping(address => bool) public isWallet;
    mapping(address => address[]) public wallets;

    /// @dev Returns number of wallets by creator.
    /// @param creator Contract creator.
    /// @return Returns number of wallets by creator.
    function getWalletsCount(address creator) public view returns (uint256 count) {
        count = wallets[creator].length;
    }

    /// @dev Allows verified creation of multisignature wallet.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    /// @return Returns wallet address.
    function create(address[] _owners, uint _required) public returns (address wallet) {
        wallet = new MultiSigWallet(_owners, _required);
        isWallet[wallet] = true;
        wallets[msg.sender].push(wallet);
        emit WalletCreated(msg.sender, wallet);
    }
}
