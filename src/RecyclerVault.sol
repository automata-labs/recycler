// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { UUPSUpgradeable as ERC1967Implementation } from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IManager } from "./interfaces/external/IManager.sol";
import { IOnChainVoteL1 } from "./interfaces/external/IOnChainVoteL1.sol";
import { IRewards } from "./interfaces/external/IRewards.sol";
import { IStaking } from "./interfaces/external/IStaking.sol";
import {
    IRecyclerVaultV1,
    IRecyclerVaultV1Actions,
    IRecyclerVaultV1StateDerived
} from "./interfaces/v1/IRecyclerVaultV1.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Epoch } from "./libraries/data/Epoch.sol";
import { State } from "./libraries/data/State.sol";
import { Cast } from "./libraries/Cast.sol";
import { SafeTransfer } from "./libraries/SafeTransfer.sol";
import { RecyclerStorageV1 } from "./RecyclerStorage.sol";

contract RecyclerVaultV1 is IRecyclerVaultV1, ERC1967Implementation, RecyclerStorageV1 {
    using Cast for uint256;
    using Epoch for Epoch.Data;
    using SafeTransfer for address;
    using State for State.Data;

    /// @notice Converts an account's buffer into shares if the buffer's epoch has been filled -
    /// otherwise the function does nothing.
    modifier tick(address account) {
        stateOf[account] = _tick(account);
        _;
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function initialize(
        address asset_,
        address staking_,
        address onchainvote_,
        address rewards_,
        address manager_,
        uint256 dust_,
        uint256 capacity_,
        uint256 prepare_
    )
        external
        auth
    {
        require(
            asset_ != address(0) &&
            staking_ != address(0) &&
            onchainvote_ != address(0) &&
            rewards_ != address(0) &&
            manager_ != address(0),
            "Address is zero"
        );

        asset = asset_;
        staking = staking_;
        onchainvote = onchainvote_;
        rewards = rewards_;
        manager = manager_;
        dust = dust_;
        capacity = capacity_;

        epochOf[0].filled = true;
        prepare(prepare_);
    }

    /**
     * ERC-20
     */

    /// @inheritdoc IERC20Metadata
    function name()
        public
        pure
        returns (string memory)
    {
        return "(Re)cycler Staked Tokemak";
    }

    /// @inheritdoc IERC20Metadata
    function symbol()
        external
        pure
        returns (string memory)
    {
        return "(re)TOKE";
    }

    /// @inheritdoc IERC20Metadata
    function decimals()
        external
        pure
        returns (uint8)
    {
        return 18;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account)
        public
        view
        returns (uint256 shares)
    {
        return _tick(account).shares;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256)
        external
        view
        noauth
        playback
        returns (bool)
    {
        revert("Transfers not supported");
    }

    /// @inheritdoc IERC20
    function transferFrom(address, address, uint256)
        external
        view
        noauth
        playback
        returns (bool)
    {
        revert("Transfers not supported");
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 coins)
        external
        noauth
        returns (bool)
    {
        _approve(msg.sender, spender, coins);
        return true;
    }

    /**
     * ERC-4626
     */
    
    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        returns (uint256)
    {
        return IERC20(asset).balanceOf(address(this)) + IERC20(staking).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function assetsOf(address account)
        external
        view
        returns (uint256 assets)
    {
        State.Data memory state = _tick(account);

        assets += state.buffer;

        if (totalSupply > 0)
            assets += (state.shares * (totalActive())) / totalSupply;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets)
        public
        view
        returns (uint256)
    {
        uint256 supply = totalSupply;
        uint256 active = totalActive();

        if (active > 0) {
            uint256 shares = (assets * supply) / active;
            return (shares == 0) ? assets : shares;
        } else {
            return assets;
        }
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets, uint256 epoch)
        public
        view
        returns (uint256)
    {
        uint256 supply = epochOf[epoch].shares;
        uint256 active = epochOf[epoch].buffer;

        if (active > 0) {
            uint256 shares = (assets * supply) / active;
            return (shares == 0) ? 0 : shares;
        } else {
            return 0;
        }
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares)
        public
        view
        returns (uint256)
    {
        if (totalSupply > 0)
            return (shares * (totalActive())) / totalSupply;
        else
            return 0;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address)
        external
        view
        returns (uint256 maxAssets)
    {
        return capacity - totalActive();
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256)
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address to)
        external
        noauth
        lock
        playback
        tick(to)
        returns (uint256)
    {
        require(assets > dust, "Insufficient deposit");
        require(assets + _balanceOf(asset, address(this)) <= capacity, "Capacity overflow");
        // check that current epoch is depositable
        require(!epochOf[cursor].filled && _blockTimestamp() <= epochOf[cursor].deadline, "Epoch expired");
        // if a past buffer exists that didn't get cleared by tick, the revert
        // cannot store to queued deposits at once
        require(stateOf[to].cycle == 0, "Withdrawal in-process");
        require(stateOf[to].epoch == cursor || stateOf[to].buffer == 0, "Buffer exists");

        // pull assets
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // update state
        epochOf[cursor].buffer += assets.u104();
        totalBuffer += assets;
        stateOf[to].epoch = cursor.u32();
        stateOf[to].buffer += assets.u96();

        IStaking(staking).deposit(assets);

        emit Transfer(address(0), to, assets);
    }

    /// @inheritdoc IERC4626
    function maxRequest(address account)
        external
        view
        returns (uint256 maxAssets)
    {
        State.Data memory state = stateOf[account];
            
        if (state.cycle > 0 && state.cycle != IManager(manager).getCurrentCycleIndex())
            return 0;
        else
            return convertToAssets(state.shares);
    }

    /// @inheritdoc IERC4626
    function previewRequest(uint256 assets)
        external
        view
        returns (uint256 shares)
    {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function request(uint256 assets, address from)
        external
        noauth
        lock
        tick(msg.sender)
        returns (uint256 shares)
    {
        require(assets > 0, "Insufficient withdrawal request");
        require(stateOf[msg.sender].epoch == 0, "Deposit in-process");
        require(stateOf[msg.sender].cycle == 0 || stateOf[msg.sender].cycle == cycleLock, "Balance withdrawal in-process");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(cycleLock <= cycleNow, "Vault withdrawal in-process");
        _withdrawAll(cycleNow);
        _decreaseAllowance(from, assets);
        shares = convertToShares(assets);

        // update state
        cycleLock = cycleNow + 2;
        stateOf[msg.sender].cycle = (cycleNow + 2).u32();
        stateOf[msg.sender].buffer += assets.u96();
        stateOf[msg.sender].shares -= shares.u96();

        IStaking(staking).requestWithdrawal(assets, 0);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address account)
        external
        view
        returns (uint256)
    {
        uint256 cycle = stateOf[account].cycle;
            
        if (cycle > 0 && cycle <= IManager(manager).getCurrentCycleIndex())
            return stateOf[account].buffer;
        else
            return 0;
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets)
        external
        view
        returns (uint256 shares)
    {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address to, address from)
        external
        noauth
        lock
        tick(msg.sender)
        returns (uint256)
    {
        require(assets > 0, "Insufficient withdrawal");
        require(stateOf[msg.sender].epoch == 0, "Deposit in-process");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(stateOf[msg.sender].cycle <= cycleNow, "Invalid cycle");
        _withdrawAll(cycleNow);
        _decreaseAllowance(from, assets);
        
        stateOf[msg.sender].buffer -= assets.u96();

        if (stateOf[msg.sender].buffer == 0)
            stateOf[msg.sender].cycle = 0;

        asset.safeTransfer(to, assets);

        return 0;
    }

    /**
     * Views
     */

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function getState(address account)
        external
        view
        returns (State.Data memory)
    {
        return stateOf[account];
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function getEpoch(uint256 index)
        external
        view
        returns (Epoch.Data memory)
    {
        return epochOf[index];
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function getRollover()
        external
        view
        returns (bool)
    {
        if (epochOf[cursor].filled || epochOf[cursor].deadline < _blockTimestamp()) {
            return true;
        } else {
            return false;
        }
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function totalActive()
        public
        view
        returns (uint256)
    {
        uint256 staked = IERC20(staking).balanceOf(address(this));
        return (staked > totalBuffer) ? staked - totalBuffer : 0;
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function totalQueued()
        external
        view
        returns (uint256)
    {
        return totalBuffer;
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function activeOf(address account)
        external
        view
        returns (uint256)
    {
        if (totalSupply > 0)
            return (balanceOf(account) * (totalActive())) / totalSupply;
        else
            return 0;
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function queuedOf(address account)
        external
        view
        returns (uint256)
    {
        State.Data memory state = _tick(account);
        
        if (state.epoch > 0)
            return state.buffer;
        else
            return 0;
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function requestedOf(address account)
        external
        view
        returns (uint256)
    {
        uint256 cycle = stateOf[account].cycle;

        if (cycle > 0 && cycle > IManager(manager).getCurrentCycleIndex())
            return stateOf[account].buffer;
        else
            return 0;
    }

    /**
     * Maintainance
     */

    /// @inheritdoc IRecyclerVaultV1Actions
    function poke(address account)
        external
    {
        stateOf[account] = _tick(account);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function prepare(uint256 amount)
        public
        auth
    {
        IERC20(asset).approve(staking, amount);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function next(uint32 deadline)
        public
        auth
        returns (uint256 id)
    {
        epochOf[(id = ++cursor)].deadline = deadline;
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function fill(uint256 epoch)
        public
        auth
        returns (uint256 shares)
    {
        require(epoch > 0, "Invalid epoch");
        require(epochOf[epoch - 1].filled, "Discontinuity");

        shares = convertToShares(epochOf[epoch].buffer);
        totalSupply += shares;
        totalBuffer -= epochOf[epoch].buffer;
        epochOf[epoch].shares = shares.u104();
        epochOf[epoch].filled = true;
    }

    /**
     * External helpers
     */

    /// @inheritdoc IRecyclerVaultV1Actions
    function _vote(IOnChainVoteL1.UserVotePayload calldata data)
        external
        auth
    {
        IOnChainVoteL1(onchainvote).vote(data);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        external
        auth
    {
        IRewards(rewards).claim(recipient, v, r, s);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _deposit(uint256 amount)
        external
        auth
    {
        IStaking(staking).deposit(amount);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _requestWithdrawal(uint256 amount)
        external
        auth
    {
        IStaking(staking).requestWithdrawal(amount, 0);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _withdraw(uint256 amount)
        external
        auth
    {
        IStaking(staking).withdraw(amount);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _withdrawAll(uint256 currentCycle)
        public
        returns (uint256)
    {
        (uint256 cycleLock, uint256 amount) =
            IStaking(staking).withdrawalRequestsByIndex(address(this), 0);

        if (currentCycle >= cycleLock && amount > 0) {
            IStaking(staking).withdraw(amount);
            return amount;
        } else {
            return 0;
        }
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function _depositWithFee(uint256 amount)
        public
        auth
    {
        IStaking(staking).deposit(amount);

        // The equation for minting the fee as shares to the maintainer is defined as:
        //
        // fee_percentage = fee / max_fee
        //
        //                        rewards * fee_percentage
        // shares = ---------------------------------------------------- * total_shares
        //           total_supply + rewards - (rewards * fee_percentage)
        //
        // and incorporates a similar behaviour as Lido's [1]. The function must include the rewards
        // that otherwise goes to depositors in the denominator so that the fee sent to the
        // maintainer does not get compounding. So the maintainer's shares can be thought of as a
        // deposit in an epoch, not earning until next cycle.
        //
        // [1]: https://github.com/lidofinance/lido-dao/blob/master/contracts/0.4.24/Lido.sol
        if (fee > 0 && maintainer != address(0)) {
            uint256 fees = (amount * fee) / MAX_FEE;
            uint256 shares;

            if (totalSupply == 0 || totalActive() - fees == 0) {
                shares = fees;
            } else {
                shares = (fees * totalSupply) / (totalActive() - fees);
            }

            totalSupply += shares;
            stateOf[maintainer].shares += shares.u96();
        }
    }

    /**
     * Internal helpers
     */
    
    /// @notice Returns a ticked account.
    /// @dev Increases shares and removes buffer, if clearable.
    function _tick(address account)
        internal
        view
        returns (State.Data memory)
    {
        State.Data memory state = stateOf[account];

        if (state.epoch > 0 && epochOf[state.epoch].filled) {
            state.shares += convertToShares(state.buffer, state.epoch).u96();
            delete state.epoch;
            delete state.buffer;
        }

        return state;
    }

    /// @notice Helper approve function.
    function _approve(address owner, address spender, uint256 coins)
        internal
    {
        allowance[owner][spender] = coins;
        emit Approval(owner, spender, coins);
    }

    /// @notice Decreases allowance - useful for burning, exiting, etc.
    function _decreaseAllowance(address from, uint256 coins)
        internal
    {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max) {
                _approve(from, msg.sender, allowed - coins);
            }
        }
    }

    /// @notice The balance of a token for this contract.
    function _balanceOf(address token, address account)
        internal
        view
        returns (uint256 balance)
    {
        (bool success, bytes memory returndata) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, account)
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }

    /// @notice Returns the block timestamp casted to `uint32`.
    function _blockTimestamp()
        internal
        view
        returns (uint32)
    {
        return uint32(block.timestamp);
    }

    /// @dev Important to authorize the upgrades.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        auth
    {}
}
