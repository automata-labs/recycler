// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

import { IERC4626 } from "../IERC4626.sol";

interface IRecyclerStorageV1State is IERC20, IERC4626 {
    /// @notice The Tokemak staking contract.
    function staking() external view returns (address);
    /// @notice The On-chain voting contract.
    function onchainvote() external view returns (address);
    /// @notice The Rewards contract.
    function rewards() external view returns (address);
    /// @notice The Manager contract.
    function manager() external view returns (address);

    /// @notice The min deposit of the vault.
    function dust() external view returns (uint256);
    /// @notice The max capacity of the vault.
    function capacity() external view returns (uint256);
    /// @notice The current epoch id.
    function cursor() external view returns (uint256);
    /// @notice The fee paid to the maintainer.
    function fee() external view returns (uint256);
    /// @notice The maintainer of the vault.
    /// @dev Receives the fee when calling `claim`, if non-zero.
    function maintainer() external view returns (address);
    /// @notice The last used min cycle index for withdrawal.
    function cycleLock() external view returns (uint256);

    /// @notice The total amount of tokens being buffered into shares.
    function totalBuffer() external view returns (uint256);

    /// @notice The mapping of states for every account.
    function stateOf(address account) external view returns (uint32, uint32, uint96, uint96);
    /// @notice The mapping of epochs.
    function epochOf(uint256 epoch) external view returns (uint32, uint104, uint104, bool);
}
