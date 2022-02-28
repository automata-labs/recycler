// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

import { IERC4626 } from "../IERC4626.sol";

interface IRecyclerStorageV1Actions is IERC20, IERC4626 {
    function setAsset(address asset_) external;
    function setStaking(address staking_) external;
    function setOnChainVote(address onchainvote_) external;
    function setRewards(address rewards_) external;
    function setManager(address manager_) external;
    function setDust(uint256 dust_) external;
    function setCapacity(uint256 capacity_) external;
    function setDeadline(uint256 epoch, uint32 deadline) external;
    function setMaintainer(address maintainer_) external;
    function setFee(uint256 fee_) external;
}
