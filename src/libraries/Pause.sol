// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Auth.sol";

contract Pause is Auth {
    /// @notice Emitted when a function is paused.
    event Paused(bytes4 sig);
    /// @notice Emitted when a function is unpaused.
    event Unpaused(bytes4 sig);

    /// @dev The mapping from function sig to state.
    mapping(bytes4 => uint256) public paused;

    /// @notice Authorize an address.
    /// @dev Can only be called by already authorized contracts.
    function pause(bytes4 sig) external virtual auth {
        paused[sig] = 1;
        emit Paused(sig);
    }

    /// @notice Unauthorize an address.
    /// @dev Can only be called by already authorized contracts.
    function unpause(bytes4 sig) external virtual auth {
        paused[sig] = 0;
        emit Unpaused(sig);
    }

    modifier playback {
        require(paused[msg.sig] == 0, "Paused");
        _;
    }
}
