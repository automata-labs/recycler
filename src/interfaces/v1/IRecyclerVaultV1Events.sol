// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerVaultV1Events {
    /// @notice Emitted when `request` is called.
    event Request(address indexed sender, address indexed from, uint256 assets, uint256 shares);
    /// @notice Emitted when creating a new epoch.
    /// @param sender The `msg.sender`.
    /// @param cursor The epoch id of the created epoch.
    /// @param deadline The deadline mint unix timestamp of the epoch.
    event Next(address indexed sender, uint256 indexed cursor, uint32 deadline);
    /// @notice Emitted when an epoch is filled.
    /// @param sender The `msg.sender`.
    /// @param epoch The id of the epoch that was filled.
    /// @param assets The amount of assets that was deposited into the epoch when it was open.
    /// @param shares The amount of shares issued to the epoch when it was filled.
    event Fill(address indexed sender, uint256 indexed epoch, uint256 assets, uint256 shares);
}
