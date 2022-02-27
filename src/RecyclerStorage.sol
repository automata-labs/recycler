// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { Epoch } from "./libraries/data/Epoch.sol";
import { State } from "./libraries/data/State.sol";
import { Auth } from "./libraries/Auth.sol";
import { Lock } from "./libraries/Lock.sol";
import { Pause } from "./libraries/Pause.sol";

abstract contract RecyclerStorageV1 is Auth, Pause, Lock, IERC20, IERC20Metadata {
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

    /// @notice Throws when the epoch parameters is invalid (0).
    error InvalidEpoch();
    /// @notice Throws when the fee is set over 100%.
    error InvalidFee();

    /// @notice The max fee that can be set.
    uint256 internal constant MAX_FEE = 1e4;
    /// @notice The capped fee at 10%.
    uint256 internal constant CAP_FEE = 1e3;

    /// @notice The Tokemak token.
    address public asset;
    /// @notice The Tokemak staking contract.
    address public staking;
    /// @notice The On-chain voting contract.
    address public onchainvote;
    /// @notice The Rewards contract.
    address public rewards;
    /// @notice The Manager contract.
    address public manager;

    /// @notice The min deposit of the vault.
    uint256 public dust;
    /// @notice The max capacity of the vault.
    uint256 public capacity;
    /// @notice The current epoch id.
    uint256 public cursor;
    /// @notice The maintainer of the vault.
    /// @dev Receives the fee when calling `claim`, if non-zero.
    address public maintainer;
    /// @notice The fee paid to the maintainer.
    uint256 public fee;
    /// @notice The last used min cycle index for withdrawal.
    uint256 public cycleLock;

    /// @notice The total amount of shares issued.
    uint256 public totalSupply;
    /// @notice The total amount of tokens being buffered into shares.
    uint256 public totalBuffer;

    /// @notice The mapping of states for every account.
    mapping(address => State.Data) public stateOf;
    /// @notice The mapping of epochs.
    mapping(uint256 => Epoch.Data) public epochOf;
    /// @inheritdoc IERC20
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * Setters
     */

    function setAsset(address asset_)
        external
        auth
    {
        asset = asset_;
        emit SetAsset(asset);
    }

    function setStaking(address staking_)
        external
        auth
    {
        staking = staking_;
        emit SetStaking(staking);
    }

    function setOnChainVote(address onchainvote_)
        external
        auth
    {
        onchainvote = onchainvote_;
        emit SetOnChainVote(onchainvote);
    }

    function setRewards(address rewards_)
        external
        auth
    {
        rewards = rewards_;
        emit SetRewards(rewards);
    }

    function setManager(address manager_)
        external
        auth
    {
        manager = manager_;
        emit SetManager(manager);
    }

    function setDust(uint256 dust_)
        external
        auth
    {
        dust = dust_;
        emit SetDust(dust);
    }

    function setCapacity(uint256 capacity_)
        external
        auth
    {
        capacity = capacity_;
        emit SetCapacity(dust);
    }

    function setDeadline(uint256 epoch, uint32 deadline)
        external
        auth
    {
        if (epoch == 0)
            revert InvalidEpoch();

        epochOf[epoch].deadline = deadline;
        emit SetDeadline(epoch, deadline);
    }

    function setMaintainer(address maintainer_)
        external
        auth
    {
        maintainer = maintainer_;
        emit SetMaintainer(maintainer);
    }

    function setFee(uint256 fee_)
        external
        auth
    {
        if (fee_ > CAP_FEE)
            revert InvalidFee();

        fee = fee_;
        emit SetFee(fee);
    }
}
