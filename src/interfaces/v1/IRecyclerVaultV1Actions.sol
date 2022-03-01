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
        uint256 capacity_
    ) external;
    /// @notice Initiate a withdrawal.
    /// @dev Does a call to Tokemak's `requestWithdrawal` function.
    /// @dev Only one withdrawal process can be done at a time, which should be fine given that the
    /// wait time is 1 cycle. But, the logic supports longer waiting cycles if required.
    function request(uint256 assets, address from) external returns (uint256 shares);

    /// @notice Approve an amount of assets from the vault.
    /// @param assets The amount to approve.
    function give(uint256 assets) external;
    /// @notice Vote on Tokemak reactors using the Recycler.
    /// @dev Each reactor key will be checked against a mapping to see if it's valid.
    function vote(IOnChainVoteL1.UserVotePayload calldata data) external;
    /// @notice Claim asset rewards.
    function claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;
    /// @notice Deposit assets from the vault to the `staking` contract.
    function stake(uint256 assets) external;
    function cache() external;
    /// @notice Rollover the vault to the next cycle.
    /// @notice Cache the values and sync cycle.
    function rollover() external;
    /// @notice Rollover the vault to the next cycle.
    /// @notice Cache the values, claim rewards, stake rewards and set new deadline.
    function compound(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    /// @notice Withdraw all assets possible from the `staking` contract.
    function withdrawAll() external;

    // function _vote(IOnChainVoteL1.UserVotePayload calldata data) external;
    
    // function _claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;
    
    // function _deposit(uint256 amount) external;
    // /// @notice Request withdrawal for assetes from the `staking` contract.
    // function _requestWithdrawal(uint256 amount) external;
    // /// @notice Withdraw assets from the `staking` contract.
    // function _withdraw(uint256 amount) external;
    // function _withdrawAll(uint256 currentCycle) external returns (uint256);
    // /// @notice Deposit assetes from the vault, and mint shares for the `maintainer`.
    // function _depositWithFee(uint256 amount) external;
}
