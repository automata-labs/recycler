// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerVaultV1Events {
    /// @notice Emitted when `cache` is called.
    event Cached(address indexed sender, uint256 indexed cycle, uint256 totalSupplyCache, uint256 totalAssetsCache);
    /// @notice Emitted when `request` is called.
    event Request(address indexed sender, address indexed from, uint256 assets, uint256 shares);
}
