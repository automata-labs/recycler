// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerErrors {
    /// @notice Throws when trying to mint when a buffer still exists and cannot be ticked/poked.
    error BufferExists();
    /// @notice Throws when permit deadline has expired.
    error DeadlineExpired();
    /// @notice Throws when trying to fill an epoch with a prev-sibling that's not filled.
    error Discontinuity();
    /// @notice Throws when minting on an latest epoch that's dead or filled.
    error EpochExpired();
    /// @notice Throws there's an insufficient amount from a transfer pull request.
    error InsufficientTransfer();
    /// @notice Throws when conversion to shares gives zero.
    error InsufficientExchange();
    /// @notice Throws when the deadline is invalid (0).
    error InvalidDeadline();
    /// @notice Throws when the epoch parameters is invalid (0).
    error InvalidEpoch();
    /// @notice Throws when the fee is set over 100%.
    error InvalidFee();
    /// @notice Throws when the permit signature is invalid.
    error InvalidSignature();
    /// @notice Throws when trying to sweep an valid token.
    error InvalidToken();
    /// @notice Throws when the max capacity is exceeded.
    error OverflowCapacity();
    /// @notice Throws when an amount parameter is less than dust.
    error ParameterDust();
    /// @notice Throws when an amount parameter is zero.
    error ParameterZero();
    /// @notice Throws when the selector is not matchable.
    error UndefinedSelector();
}
