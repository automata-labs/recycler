// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerEvents {
    /// @notice Emitted when capacity is set.
    /// @param capacity The set capacity value.
    event SetCapacity(uint256 capacity);
    /// @notice Emitted when a new deadline is set for an epoch
    /// @param epoch The set capacity value.
    event SetDeadline(uint256 epoch, uint32 deadline);
    /// @notice Emitted when dust is set.
    /// @param dust The set dust value.
    event SetDust(uint256 dust);
    /// @notice Emitted when fee is set.
    /// @param fee The set fee value.
    event SetFee(uint256 fee);
    /// @notice Emitted when a reactor key is set.
    /// @param key The reactor key.
    /// @param value The value of the reactor key.
    event SetKey(bytes32 key, bool value);
    /// @notice Emitted when maintainer is set.
    /// @param maintainer The set maintainer address.
    event SetMaintainer(address maintainer);
    /// @notice Emitted when name is set.
    /// @dev Not emitted in constructor/deployment.
    /// @param name The set dust value.
    event SetName(string name);
    /// @notice Emitted when creating a new epoch.
    /// @param sender The `msg.sender`.
    /// @param cursor The epoch id of the created epoch.
    /// @param deadline The deadline mint unix timestamp of the epoch.
    event Next(address indexed sender, uint256 indexed cursor, uint32 deadline);
    /// @notice Emitted when buffering coins into the vault.
    /// @param sender The `msg.sender`.
    /// @param to The address to receive the buffered coins balance.
    /// @param buffer The amount of coins being buffered.
    event Mint(address indexed sender, address indexed to, uint256 buffer);
    /// @notice Emitted when burning shares for coins.
    /// @param sender The `msg.sender`.
    /// @param from The address to burn shares from.
    /// @param to The address to receive the redeemed coins.
    /// @param coins The amount of coins being buffered.
    event Burn(address indexed sender, address indexed from, address indexed to, uint256 coins);
    /// @notice Emitted when exiting into coins.
    /// @param sender The `msg.sender`.
    /// @param from The address to burn buffer from.
    /// @param to The address to receive the buffered coins.
    /// @param buffer The amount of coins being withdrawn.
    event Exit(address indexed sender, address indexed from, address indexed to, uint256 buffer);
    /// @notice Emitted when an epoch is filled.
    /// @param sender The `msg.sender`.
    /// @param epoch The id of the epoch that was filled.
    /// @param coins The amount of coins that was deposited into the epoch when it was open.
    /// @param shares The amount of shares issued to the epoch when it was filled.
    event Fill(address indexed sender, uint256 indexed epoch, uint256 coins, uint256 shares);
}
