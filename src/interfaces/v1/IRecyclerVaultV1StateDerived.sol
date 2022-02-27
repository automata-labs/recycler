// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Epoch } from "../../libraries/data/Epoch.sol";
import { State } from "../../libraries/data/State.sol";

interface IRecyclerVaultV1StateDerived {
    /// @notice Returns a state as a struct.
    function getState(address account) external view returns (State.Data memory);
    /// @notice Returns an epoch as a struct.
    function getEpoch(uint256 index) external view returns (Epoch.Data memory);
    /// @notice Returns the rollover state of the struct.
    /// @dev When the vault is rolling over, deposit should revert.
    function getRollover() external view returns (bool);
    /// @notice The total amount of assets staked in the `staking` contract.
    function totalActive() external view returns (uint256);
    /// @notice The total amount of assets being queued for deposit.
    function totalQueued() external view returns (uint256);
    /// @notice Returns the active amount of an account.
    function activeOf(address account) external view returns (uint256);
    /// @notice Returns the queued amount of an account.
    function queuedOf(address account) external view returns (uint256);
    /// @notice Returns the requested amount of an account.
    function requestedOf(address account) external view returns (uint256);
}
