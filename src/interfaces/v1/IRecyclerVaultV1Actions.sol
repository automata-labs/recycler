// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IOnChainVoteL1 } from "../external/IOnChainVoteL1.sol";
import { IRewards } from "../external/IRewards.sol";

interface IRecyclerVaultV1Actions {
    /// @notice Initializes the vault.
    function initialize(
        address asset_,
        address staking_,
        address onchainvote_,
        address rewards_,
        address manager_,
        uint256 dust_,
        uint256 capacity_,
        uint256 prepare_
    ) external;

    /// @notice Converts an account's buffer into shares if and only if the buffer's epoch has been
    /// filled, otherwise the function does nothing.
    /// @param account The account to tick.
    function poke(address account) external;
    /// @notice Approve an amount of assets from the vault.
    /// @dev Authorized function.
    /// @param amount The amount to approve.
    function prepare(uint256 amount) external;
    /// @notice Fast-forward to next epoch.
    /// @dev A new epoch can be created without the previous being filled.
    /// @dev Authorized function.
    /// @param deadline The deadline in unix timestamp.
    /// @return id The epoch id of the created epoch.
    function next(uint32 deadline) external returns (uint256 id);
    /// @notice Fill an epoch with shares (iff the previous epoch is already filled).
    /// @dev Authorized function.
    /// @param epoch The epoch id to fill.
    /// @return shares The amount of shares for the epoch `epoch`.
    function fill(uint256 epoch) external returns (uint256 shares);

    /// @notice Vote on Tokemak reactors using the Recycler.
    /// @dev Each reactor key will be checked against a mapping to see if it's valid.
    function _vote(IOnChainVoteL1.UserVotePayload calldata data) external;
    /// @notice Claim asset rewards.
    function _claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;
    /// @notice Deposit assets from the vault to the `staking` contract.
    function _deposit(uint256 amount) external;
    /// @notice Request withdrawal for assetes from the `staking` contract.
    function _requestWithdrawal(uint256 amount) external;
    /// @notice Withdraw assets from the `staking` contract.
    function _withdraw(uint256 amount) external;
    /// @notice Withdraw all assets possible from the `staking` contract.
    function _withdrawAll(uint256 currentCycle) external returns (uint256);
    /// @notice Deposit assetes from the vault, and mint shares for the `maintainer`.
    function _depositWithFee(uint256 amount) external;
}
