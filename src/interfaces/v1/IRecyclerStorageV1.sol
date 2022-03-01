// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IERC4626 } from "../IERC4626.sol";

interface IRecyclerStorageV1 is IERC20, IERC20Metadata, IERC4626 {
    /// @notice The Tokemak staking contract.
    function staking() external view returns (address);
    /// @notice The On-chain voting contract.
    function onchainvote() external view returns (address);
    /// @notice The Rewards contract.
    function rewards() external view returns (address);
    /// @notice The Manager contract.
    function manager() external view returns (address);

    /// @notice The max capacity of the vault.
    function capacity() external view returns (uint256);
    /// @notice To give the admin time to rollover the vault.
    function deadline() external view returns (uint256);
    /// @notice The expected percentage rewards from the next claim.
    /// @dev The parameters is used to decrease the minted shares on deposit. This prevents the
    /// attack where users can deposit right before the rollover and withdraw soonly after to earn 
    /// more rewards than intended.
    function rate() external view returns (uint256);
    /// @notice The amount of shares being prepared to be removed on withdrawal.
    /// @dev This relates to how the staking contract updates `balanceOf` on withdrawal, not on request.
    function buffer() external view returns (uint256);
    /// @notice The fee paid to the maintainer.
    function fee() external view returns (uint256);
    /// @notice The maintainer of the vault.
    /// @dev Receives the fee when calling `claim`, if non-zero.
    function maintainer() external view returns (address);

    /// @notice The cached supply for this cycle.
    /// @dev Used to calculate the correct amount of shares on deposit
    function totalSupplyCache() external view returns (uint256);
    /// @notice The cached assets for this cycle.
    /// @dev Used to calculate the correct amount of shares on deposit
    function totalAssetsCache() external view returns (uint256);
    /// @notice The mapping of requests.
    function requestOf(address account) external view returns (uint32, uint224);

    function setAsset(address asset_) external;
    function setStaking(address staking_) external;
    function setOnChainVote(address onchainvote_) external;
    function setRewards(address rewards_) external;
    function setManager(address manager_) external;
    function setCapacity(uint256 capacity_) external;
    function setDeadline(uint256 deadline_) external;
    function setMaintainer(address maintainer_) external;
    function setFee(uint256 fee_) external;
    function setRate(uint256 rate_) external;
}
