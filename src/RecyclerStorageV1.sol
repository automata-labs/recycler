// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

import { IRecyclerStorageV1 } from "./interfaces/v1/IRecyclerStorageV1.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Epoch } from "./libraries/data/Epoch.sol";
import { Request } from "./libraries/data/Request.sol";
import { State } from "./libraries/data/State.sol";
import { Auth } from "./libraries/Auth.sol";
import { Lock } from "./libraries/Lock.sol";
import { Pause } from "./libraries/Pause.sol";

abstract contract RecyclerStorageV1 is IRecyclerStorageV1, Auth, Pause, Lock {
    using State for State.Data;

    /// @notice Emitted when asset is set.
    /// @param asset The set asset value.
    event SetAsset(address asset);
    /// @notice Emitted when staking is set.
    /// @param staking The set staking value.
    event SetStaking(address staking);
    /// @notice Emitted when onchainvote is set.
    /// @param onchainvote The set onchainvote value.
    event SetOnChainVote(address onchainvote);
    /// @notice Emitted when rewards is set.
    /// @param rewards The set rewards value.
    event SetRewards(address rewards);
    /// @notice Emitted when manager is set.
    /// @param manager The set manager value.
    event SetManager(address manager);
    /// @notice Emitted when capacity is set.
    /// @param capacity The set capacity value.
    event SetCapacity(uint256 capacity);
    /// @notice Emitted when a new cycle is force-set.
    event SetCycle(uint256 cycle);
    /// @notice Emitted when fee is set.
    /// @param fee The set fee value.
    event SetFee(uint256 fee);
    /// @notice Emitted when maintainer is set.
    /// @param maintainer The set maintainer address.
    event SetMaintainer(address maintainer);
    /// @notice Emitted when rate is set.
    /// @param rate The set rate address.
    event SetRate(uint256 rate);

    /// @notice The max rate.
    uint256 public constant UNIT_RATE = 1e18;
    /// @notice The rate capped at 1%.
    uint256 public constant CEIL_RATE = 1e16;
    /// @notice The max fee that can be set.
    uint256 public constant UNIT_FEE = 1e4;
    /// @notice The fee capped at 10%.
    uint256 public constant CEIL_FEE = 1e3;

    /// @inheritdoc IERC4626
    address public asset;
    /// @inheritdoc IRecyclerStorageV1
    address public staking;
    /// @inheritdoc IRecyclerStorageV1
    address public onchainvote;
    /// @inheritdoc IRecyclerStorageV1
    address public rewards;
    /// @inheritdoc IRecyclerStorageV1
    address public manager;

    /// @inheritdoc IRecyclerStorageV1
    uint256 public capacity;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public rate;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public buffer;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public cycle;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public fee;
    /// @inheritdoc IRecyclerStorageV1
    address public maintainer;

    /// @inheritdoc IERC20
    uint256 public totalSupply;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public totalSupplyCache;
    /// @inheritdoc IRecyclerStorageV1
    uint256 public totalAssetsCache;
    /// @inheritdoc IERC20
    mapping(address => uint256)      public balanceOf;
    /// @inheritdoc IRecyclerStorageV1
    mapping(address => Request.Data) public requestOf;
    /// @inheritdoc IERC20
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * Setters
     */

    /// @inheritdoc IRecyclerStorageV1
    function setAsset(address asset_) external auth {
        asset = asset_;
        emit SetAsset(asset);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setStaking(address staking_) external auth {
        staking = staking_;
        emit SetStaking(staking);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setOnChainVote(address onchainvote_) external auth {
        onchainvote = onchainvote_;
        emit SetOnChainVote(onchainvote);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setRewards(address rewards_) external auth {
        rewards = rewards_;
        emit SetRewards(rewards);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setManager(address manager_) external auth {
        manager = manager_;
        emit SetManager(manager);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setCapacity(uint256 capacity_) external auth {
        capacity = capacity_;
        emit SetCapacity(capacity);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setCycle(uint256 cycle_) external auth {
        cycle = cycle_;
        emit SetCycle(cycle);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setRate(uint256 rate_) external auth {
        require(rate_ <= CEIL_RATE, "Rate too large");
        rate = rate_;
        emit SetRate(rate);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setFee(uint256 fee_) external auth {
        require(fee <= CEIL_FEE, "Fee too large");
        fee = fee_;
        emit SetFee(fee);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setMaintainer(address maintainer_) external auth {
        maintainer = maintainer_;
        emit SetMaintainer(maintainer);
    }

    /// @inheritdoc IRecyclerStorageV1
    function setTotalSupplyCache(uint256 totalSupplyCache_) external auth {
        totalSupplyCache = totalSupplyCache_;
    }

    /// @inheritdoc IRecyclerStorageV1
    function setTotalAssetsCache(uint256 totalAssetsCache_) external auth {
        totalAssetsCache = totalAssetsCache_;
    }
}
