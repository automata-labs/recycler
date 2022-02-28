// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

import { IRecyclerStorageV1 } from "./interfaces/v1/IRecyclerStorageV1.sol";
import { IRecyclerStorageV1Actions } from "./interfaces/v1/IRecyclerStorageV1Actions.sol";
import { IRecyclerStorageV1State } from "./interfaces/v1/IRecyclerStorageV1State.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Epoch } from "./libraries/data/Epoch.sol";
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
    /// @notice Emitted when dust is set.
    /// @param dust The set dust value.
    event SetDust(uint256 dust);
    /// @notice Emitted when capacity is set.
    /// @param capacity The set capacity value.
    event SetCapacity(uint256 capacity);
    /// @notice Emitted when a new deadline is set for an epoch
    /// @param epoch The set capacity value.
    event SetDeadline(uint256 epoch, uint32 deadline);
    /// @notice Emitted when maintainer is set.
    /// @param maintainer The set maintainer address.
    event SetMaintainer(address maintainer);
    /// @notice Emitted when fee is set.
    /// @param fee The set fee value.
    event SetFee(uint256 fee);

    /// @notice The max fee that can be set.
    uint256 internal constant MAX_FEE = 1e4;
    /// @notice The capped fee at 10%.
    uint256 internal constant CAP_FEE = 1e3;

    /// @inheritdoc IERC4626
    address public asset;
    /// @inheritdoc IRecyclerStorageV1State
    address public staking;
    /// @inheritdoc IRecyclerStorageV1State
    address public onchainvote;
    /// @inheritdoc IRecyclerStorageV1State
    address public rewards;
    /// @inheritdoc IRecyclerStorageV1State
    address public manager;

    /// @inheritdoc IRecyclerStorageV1State
    uint256 public dust;
    /// @inheritdoc IRecyclerStorageV1State
    uint256 public capacity;
    /// @inheritdoc IRecyclerStorageV1State
    uint256 public cursor;
    /// @inheritdoc IRecyclerStorageV1State
    uint256 public fee;
    /// @inheritdoc IRecyclerStorageV1State
    /// @dev Receives the fee when calling `claim`, if non-zero.
    address public maintainer;
    /// @inheritdoc IRecyclerStorageV1State
    uint256 public cycleLock;

    /// @inheritdoc IERC20
    uint256 public totalSupply;
    /// @inheritdoc IRecyclerStorageV1State
    uint256 public totalBuffer;

    /// @inheritdoc IRecyclerStorageV1State
    mapping(address => State.Data) public stateOf;
    /// @inheritdoc IRecyclerStorageV1State
    mapping(uint256 => Epoch.Data) public epochOf;
    /// @inheritdoc IERC20
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * Setters
     */

    /// @inheritdoc IRecyclerStorageV1Actions
    function setAsset(address asset_)
        external
        auth
    {
        asset = asset_;
        emit SetAsset(asset);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setStaking(address staking_)
        external
        auth
    {
        staking = staking_;
        emit SetStaking(staking);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setOnChainVote(address onchainvote_)
        external
        auth
    {
        onchainvote = onchainvote_;
        emit SetOnChainVote(onchainvote);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setRewards(address rewards_)
        external
        auth
    {
        rewards = rewards_;
        emit SetRewards(rewards);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setManager(address manager_)
        external
        auth
    {
        manager = manager_;
        emit SetManager(manager);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setDust(uint256 dust_)
        external
        auth
    {
        dust = dust_;
        emit SetDust(dust);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setCapacity(uint256 capacity_)
        external
        auth
    {
        capacity = capacity_;
        emit SetCapacity(dust);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setDeadline(uint256 epoch, uint32 deadline)
        external
        auth
    {
        require(epoch > 0, "Invalid epoch");
        epochOf[epoch].deadline = deadline;
        emit SetDeadline(epoch, deadline);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setMaintainer(address maintainer_)
        external
        auth
    {
        maintainer = maintainer_;
        emit SetMaintainer(maintainer);
    }

    /// @inheritdoc IRecyclerStorageV1Actions
    function setFee(uint256 fee_)
        external
        auth
    {
        require(fee <= CAP_FEE, "Fee overflow");
        fee = fee_;
        emit SetFee(fee);
    }
}
