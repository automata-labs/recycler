// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { UUPSUpgradeable as ERC1967Implementation } from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IManager } from "./interfaces/external/IManager.sol";
import { IOnChainVoteL1 } from "./interfaces/external/IOnChainVoteL1.sol";
import { IRewards } from "./interfaces/external/IRewards.sol";
import { IStaking } from "./interfaces/external/IStaking.sol";
import { Epoch } from "./libraries/data/Epoch.sol";
import { State } from "./libraries/data/State.sol";
import { Cast } from "./libraries/Cast.sol";
import { SafeTransfer } from "./libraries/SafeTransfer.sol";
import { RecyclerStorageV1 } from "./RecyclerStorage.sol";

contract RecyclerVaultV1 is ERC1967Implementation, RecyclerStorageV1 {
    using Cast for uint256;
    using Epoch for Epoch.Data;
    using SafeTransfer for address;
    using State for State.Data;

    /// @notice Converts an account's buffer into shares if the buffer's epoch has been filled -
    ///     otherwise the function does nothing.
    modifier tick(address account) {
        stateOf[account] = _tick(account);
        _;
    }

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
     * ERC-4626
     */

    function name()
        public
        pure
        returns (string memory)
    {
        return "(Re)cycler Staked Tokemak";
    }

    function symbol()
        external
        pure
        returns (string memory)
    {
        return "(re)TOKE";
    }

    function decimals()
        external
        pure
        returns (uint8)
    {
        return 18;
    }

    /// @dev Returns the total amount of assets in `this` contract and in the `staking` contract.
    function totalAssets()
        public
        view
        returns (uint256)
    {
        return IERC20(asset).balanceOf(address(this)) + IERC20(staking).balanceOf(address(this));
    }

    /// @notice The total amount of assets staked in the `staking` contract.
    function totalActive()
        public
        view
        returns (uint256)
    {
        uint256 staked = IERC20(staking).balanceOf(address(this));
        return (staked > totalBuffer) ? staked - totalBuffer : 0;
    }

    function totalQueued()
        external
        view
        returns (uint256)
    {
        return totalBuffer;
    }

    /// @notice Returns the shares of an account.
    function balanceOf(address account)
        public
        view
        returns (uint256 shares)
    {
        return _tick(account).shares;
    }

    /// @notice Returns the assets of an account.
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

    /// @notice Returns the active amount of an account.
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

    /// @notice Returns the queued amount of an account.
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

    function withdrawableOf(address account)
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

    function convertToAssets(uint256 shares)
        external
        view
        returns (uint256)
    {
        if (totalSupply > 0)
            return (shares * (totalActive())) / totalSupply;
        else
            return 0;
    }

    function transfer(address, uint256)
        external
        view
        noauth
        playback
        returns (bool)
    {
        revert("Transfers not supported");
    }

    function transferFrom(address, address, uint256)
        external
        view
        noauth
        playback
        returns (bool)
    {
        revert("Transfers not supported");
    }

    function approve(address spender, uint256 coins)
        external
        noauth
        returns (bool)
    {
        _approve(msg.sender, spender, coins);
        return true;
    }

    /**
     * Views
     */

    function getState(address account)
        external
        view
        returns (State.Data memory)
    {
        return stateOf[account];
    }

    function getEpoch(uint256 index)
        external
        view
        returns (Epoch.Data memory)
    {
        return epochOf[index];
    }

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

    /**
     * Actions
     */

    function deposit(uint256 amount, address to)
        external
        noauth
        lock
        playback
        tick(to)
    {
        require(amount > dust, "Insufficient deposit");
        require(amount + _balanceOf(asset, address(this)) <= capacity, "Capacity overflow");
        // check that current epoch is depositable
        require(!epochOf[cursor].filled && _blockTimestamp() <= epochOf[cursor].deadline, "Epoch expired");
        // if a past buffer exists that didn't get cleared by tick, the revert
        // cannot store to queued deposits at once
        require(stateOf[to].cycle == 0, "Withdrawal in-process");
        require(stateOf[to].epoch == cursor || stateOf[to].buffer == 0, "Buffer exists");

        // pull assets
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // update state
        epochOf[cursor].buffer += amount.u104();
        totalBuffer += amount;
        stateOf[to].epoch = cursor.u32();
        stateOf[to].buffer += amount.u96();

        IStaking(staking).deposit(amount);

        emit Transfer(address(0), to, amount);
    }

    function request(uint256 amount)
        external
        noauth
        lock
        tick(msg.sender)
    {
        require(amount > 0, "Insufficient withdrawal request");
        require(stateOf[msg.sender].epoch == 0, "Deposit in-process");
        require(stateOf[msg.sender].cycle == 0 || stateOf[msg.sender].cycle == cycleLock, "Balance withdrawal in-process");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(cycleLock <= cycleNow, "Vault withdrawal in-process");
        _withdrawAll(cycleNow);

        // update state
        cycleLock = cycleNow + 2;
        stateOf[msg.sender].cycle = (cycleNow + 2).u32();
        stateOf[msg.sender].buffer += amount.u96();
        stateOf[msg.sender].shares -= convertToShares(amount).u96();

        IStaking(staking).requestWithdrawal(amount, 0);
    }

    function withdraw(uint256 amount, address to)
        external
        noauth
        lock
        tick(msg.sender)
    {
        require(amount > 0, "Insufficient withdrawal");
        require(stateOf[msg.sender].epoch == 0, "Deposit in-process");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(stateOf[msg.sender].cycle <= cycleNow, "Invalid cycle");
        _withdrawAll(cycleNow);

        stateOf[msg.sender].buffer -= amount.u96();

        if (stateOf[msg.sender].buffer == 0)
            stateOf[msg.sender].cycle = 0;

        asset.safeTransfer(to, amount);
    }

    /**
     * Maintainance
     */

    function poke(address account)
        external
    {
        stateOf[account] = _tick(account);
    }

    function prepare(uint256 amount)
        public
        auth
    {
        IERC20(asset).approve(staking, amount);
    }

    function next(uint32 deadline)
        public
        auth
        returns (uint256 id)
    {
        epochOf[(id = ++cursor)].deadline = deadline;
    }

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
     * Tokemak
     */

    function _vote(IOnChainVoteL1.UserVotePayload calldata data)
        external
        auth
    {
        IOnChainVoteL1(onchainvote).vote(data);
    }

    function _claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        external
        auth
    {
        IRewards(rewards).claim(recipient, v, r, s);
    }

    function _deposit(uint256 amount)
        external
        auth
    {
        IStaking(staking).deposit(amount);
    }

    function _requestWithdrawal(uint256 amount)
        external
        auth
    {
        IStaking(staking).requestWithdrawal(amount, 0);
    }

    function _withdraw(uint256 amount)
        external
        auth
    {
        IStaking(staking).withdraw(amount);
    }

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
     * Internal
     */
    
    /// @notice Ticks an account if there's clearable buffer.
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

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        auth
    {}
}
