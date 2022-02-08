// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICallback {
    /// @notice Callback function for when calling the `mint` function.
    /// @dev The target contract will have conditions for passing, the the callback is expected to
    /// fulfill those conditions, otherwise the call stack should fail.
    function mintCallback(bytes calldata data) external;
}
