// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

import { IRecyclerStorageV1 } from "./interfaces/v1/IRecyclerStorageV1.sol";
import { IRecyclerStorageV1Actions } from "./interfaces/v1/IRecyclerStorageV1Actions.sol";
import { IRecyclerStorageV1State } from "./interfaces/v1/IRecyclerStorageV1State.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Epoch } from "./libraries/data/Epoch.sol";
import { Request } from "./libraries/data/Request.sol";
import { State } from "./libraries/data/State.sol";
import { Auth } from "./libraries/Auth.sol";
import { Lock } from "./libraries/Lock.sol";
import { Pause } from "./libraries/Pause.sol";

abstract contract RecyclerStorageV1 is Auth, Pause, Lock {
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
    /// @notice Emitted when a new deadline is set for an epoch
    event SetDeadline(uint256 deadline);
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

    address public asset;
    address public staking;
    address public onchainvote;
    address public rewards;
    address public manager;

    uint256 public capacity;
    uint256 public fee;
    /// @dev Receives the fee when calling `claim`, if non-zero.
    address public maintainer;
    /// @notice To give the admin time to rollover the vault.
    uint256 public deadline;
    /// @notice The expected percentage rewards from the next claim.
    /// @dev The parameters is used to decrease the minted shares on deposit. This prevents the
    /// attack where users can deposit right before the rollover and withdraw soonly after to earn 
    /// more rewards than intended.
    uint256 public rate;
    /// @notice Buffered shares that will be removed when withdraw is called on the staking contract.
    uint256 public buffer;

    uint256 public totalSupply;
    mapping(address => uint256)      public balanceOf;
    mapping(address => Request.Data) public requestOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupplyCache;
    uint256 public totalAssetsCache;

    /**
     * Setters
     */

    function setAsset(address asset_) external auth {
        asset = asset_;
        emit SetAsset(asset);
    }

    function setStaking(address staking_) external auth {
        staking = staking_;
        emit SetStaking(staking);
    }

    function setOnChainVote(address onchainvote_) external auth {
        onchainvote = onchainvote_;
        emit SetOnChainVote(onchainvote);
    }

    function setRewards(address rewards_) external auth {
        rewards = rewards_;
        emit SetRewards(rewards);
    }

    function setManager(address manager_) external auth {
        manager = manager_;
        emit SetManager(manager);
    }

    function setCapacity(uint256 capacity_) external auth {
        capacity = capacity_;
        emit SetCapacity(capacity);
    }

    function setDeadline(uint256 deadline_) external auth {
        deadline = deadline_;
        emit SetDeadline(deadline);
    }

    function setFee(uint256 fee_) external auth {
        require(fee <= CEIL_FEE, "Fee too large");
        fee = fee_;
        emit SetFee(fee);
    }

    function setMaintainer(address maintainer_) external auth {
        maintainer = maintainer_;
        emit SetMaintainer(maintainer);
    }

    function setRate(uint256 rate_) external auth {
        require(rate_ <= CEIL_RATE, "Rate too large");
        rate = rate_;
        emit SetRate(rate);
    }
}
