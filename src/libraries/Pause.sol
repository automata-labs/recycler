// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Auth.sol";

contract Pause is Auth {
    /// @notice Emitted when a function is destroyed (paused forever).
    /// @param sig The function signature.
    event Destroyed(bytes4 sig);
    /// @notice Emitted when a function is paused.
    /// @param sig The function signature.
    event Paused(bytes4 sig);
    /// @notice Emitted when a function is unpaused.
    /// @param sig The function signature.
    event Unpaused(bytes4 sig);

    uint256 public constant DESTROY = uint256(keccak256("Pause.destroy"));

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
        require(paused[sig] != DESTROY, "Destroyed");
        paused[sig] = 0;
        emit Unpaused(sig);
    }

    /// @notice Pause a function forever.
    /// @dev This action cannot be undone. Use with caution.
    function destroy(bytes4 sig) external virtual auth {
        paused[sig] = DESTROY;
        emit Destroyed(sig);
    }

    modifier playback {
        require(paused[msg.sig] == 0, "Paused");
        _;
    }
}
