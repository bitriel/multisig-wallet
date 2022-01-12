// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./MultiSigWallet.sol";

/// @title Multi signature wallet factory - Allows creation of multisig wallet.
contract MultiSigWalletFactory {
    event WalletCreated(address creator, address wallet);

    address immutable public multisigWalletBeacon;
    address[] public wallets;

    constructor(address upgrader) {
        UpgradeableBeacon _multisigWalletBeacon = new UpgradeableBeacon(address(new MultiSigWallet()));
        _multisigWalletBeacon.transferOwnership(upgrader);
        multisigWalletBeacon = address(_multisigWalletBeacon);
    }

    /// @dev Allows verified creation of multisignature wallet.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    /// @return wallet Returns wallet address.
    function createWallet(address[] memory _owners, uint8 _required) external returns (address wallet) {
        BeaconProxy proxy = new BeaconProxy(
            multisigWalletBeacon,
            abi.encodeWithSelector(MultiSigWallet.initialize.selector, _owners, _required)
        );
        wallet = address(proxy);
        wallets.push(wallet);
        emit WalletCreated(msg.sender, wallet);
    }

    /// @dev Allows verified creation of multisignature wallet.
    /// @param data data payload for initialize a wallet.
    /// @return wallet Returns wallet address.
    function createWallet(bytes calldata data) external returns (address wallet) {
        BeaconProxy proxy = new BeaconProxy(
            multisigWalletBeacon,
            data
        );
        wallet = address(proxy);
        wallets.push(address(proxy));
        emit WalletCreated(msg.sender, address(proxy));
    }
}
