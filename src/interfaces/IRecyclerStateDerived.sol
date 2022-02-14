// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../libraries/data/Buffer.sol";
import "../libraries/data/Epoch.sol";

interface IRecyclerStateDerived {
    /// @notice The permit typehash used for `permit`.
    function PERMIT_TYPEHASH() external view returns (bytes32);
    /// @notice Returns the domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the total amount of active coins.
    function totalCoins() external view returns (uint256);
    /// @notice Returns the amount of current buffered coins.
    /// @param account The address of an account.
    /// @return The amount of tokens being buffered/queued. While `bufferOf` can show an amount if
    /// it has not been poked, `queuedOf` will show a updated value. E.g., if `bufferOf.amount` is a
    /// non-zero value, but the epoch has been filled, then `queuedOf` will return zero.
    function queuedOf(address account) external view returns (uint256);
    /// @notice Returns the epoch as a struct.
    /// @dev Convenience function.
    /// @param epoch The epoch id.
    /// @return The epoch as a struct.
    function epochAs(uint256 epoch) external view returns (Epoch.Data memory);
    /// @notice Returns the buffer of `account` as a struct.
    /// @dev Convenience function.
    /// @param account The address of an account.
    /// @return The buffer as a struct.
    function bufferAs(address account) external view returns (Buffer.Data memory);

    /// @notice Returns whether the cycle is rolling over or not.
    function rotating() external view returns (bool);
    /// @notice Converts coins to shares.
    /// @param coins The amount of coins to preview as shares.
    function coinsToShares(uint256 coins) external view returns (uint256);
    /// @notice Converts shares to coins.
    /// @param shares The amount of shares to preview as coinss.
    function sharesToCoins(uint256 shares) external view returns (uint256);
}
