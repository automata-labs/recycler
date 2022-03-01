// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { UUPSUpgradeable as ERC1967Implementation } from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IManager } from "./interfaces/external/IManager.sol";
import { IOnChainVoteL1 } from "./interfaces/external/IOnChainVoteL1.sol";
import { IRewards } from "./interfaces/external/IRewards.sol";
import { IStaking } from "./interfaces/external/IStaking.sol";
import { ITokeMigrationPool } from "./interfaces/external/ITokeMigrationPool.sol";
import { IRecyclerVaultV1 } from "./interfaces/v1/IRecyclerVaultV1.sol";
import { IRecyclerVaultV1Actions } from "./interfaces/v1/IRecyclerVaultV1Actions.sol";
import { IRecyclerVaultV1StateDerived } from "./interfaces/v1/IRecyclerVaultV1StateDerived.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Request } from "./libraries/data/Request.sol";
import { Cast } from "./libraries/Cast.sol";
import { SafeTransfer } from "./libraries/SafeTransfer.sol";
import { RecyclerStorageV1 } from "./RecyclerStorageV1.sol";

contract RecyclerVaultV1 is IRecyclerVaultV1, ERC1967Implementation, RecyclerStorageV1 {
    using Cast for uint256;
    using SafeTransfer for address;

    /// @inheritdoc IRecyclerVaultV1Actions
    function initialize(
        address asset_,
        address staking_,
        address onchainvote_,
        address rewards_,
        address manager_,
        uint256 capacity_
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
            "Address zero"
        );

        asset = asset_;
        staking = staking_;
        onchainvote = onchainvote_;
        rewards = rewards_;
        manager = manager_;
        capacity = capacity_;
        cycle = _cycle();
    }

    /**
     * ERC-20
     */

    /// @inheritdoc IERC20Metadata
    function name() public pure returns (string memory) {
        return "(Re)cycler Staked Tokemak";
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external pure returns (string memory) {
        return "(re)TOKE";
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) external pure returns (bool) {
        revert("Transfer not supported");
    }

    /// @inheritdoc IERC20
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert("Transfer not supported");
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 coins) external returns (bool) {
        _approve(msg.sender, spender, coins);

        return true;
    }

    /**
     * ERC-4626
     */

    /// @inheritdoc IERC4626
    function totalAssets() public view returns (uint256 assets) {
        assets = IERC20(staking).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function assetsOf(address account) external view returns (uint256 assets) {
        assets = convertToAssets(balanceOf[account]);
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint256 _totalAssets = totalAssets();

        if (_totalAssets > 0) {
            uint256 result = assets * totalSupply / _totalAssets;
            shares = (result == 0) ? assets : result;
        } else {
            shares = assets;
        }
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        if (totalSupply > 0)
            assets = (shares * (totalAssets())) / totalSupply;
        else
            assets = 0;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address account) external view returns (uint256 assets) {
        uint256 balance = _balanceOf(asset, account);
        uint256 remaining = capacity - totalAssets();

        if (balance > remaining)
            assets = remaining;
        else
            assets = balance;
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function maxRequest(address account) external view returns (uint256 assets) {
        assets = convertToAssets(balanceOf[account]);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address account) external view returns (uint256 assets) {
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();

        if (requestOf[account].cycle <= cycleNow)
            assets = requestOf[account].assets;
        else
            assets = 0;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        if (totalSupply == 0 || totalSupplyCache == 0) {
            shares = assets;
        } else {
            if (totalAssetsCache > 0) {
                uint256 addend = totalAssetsCache * rate / UNIT_RATE;
                shares = assets * totalSupplyCache / (totalAssetsCache + addend);
            } else {
                shares = 0;
            }
        }
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function previewRequest(uint256 assets) public view returns (uint256 shares) {
        uint256 _totalAssets = totalAssets();

        if (_totalAssets > 0)
            shares = assets * totalSupply / _totalAssets;
        else
            shares = 0;
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256) public pure returns (uint256 shares) {
        shares = 0;
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address to) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient deposit");
        require(assets + _balanceOf(staking, address(this)) <= capacity, "Capacity overflow");
        require(block.timestamp <= deadline, "Deadline");

        _cache();
        require((shares = previewDeposit(assets)) > 0, "Insufficient conversion");
        _pay(asset, msg.sender, address(this), assets);

        totalSupply += shares;
        balanceOf[to] += shares;

        _deposit(assets);
        emit Deposit(msg.sender, to, assets, shares);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function request(uint256 assets, address from) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient request");
        (uint256 lastCycle, uint256 lockCycle, uint256 requested) = _withdrawStatus();
        require(lockCycle == lastCycle + 1 || lockCycle <= lastCycle, "Vault locked");
        require((shares = previewRequest(assets)) > 0, "Insufficient conversion");
        _decreaseAllowance(from, shares);
        _withdrawAll(lastCycle, lockCycle, requested);

        // vault effects
        buffer += shares;
        // user effects
        balanceOf[from] -= shares;
        requestOf[from].cycle = (lastCycle + 1).u32();
        requestOf[from].assets += assets.u224();

        _requestWithdrawal(requested + assets);
        emit Request(msg.sender, from, assets, shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address to, address from) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient withdrawable");
        (uint256 lastCycle, uint256 lockCycle, uint256 requested) = _withdrawStatus();
        require(requestOf[from].cycle <= lastCycle, "Withdraw not matured");
        shares = previewWithdraw(assets);
        _decreaseAllowance(from, shares);
        _withdrawAll(lastCycle, lockCycle, requested);

        requestOf[from].assets -= assets.u224();
        requestOf[from].cycle = (requestOf[from].assets == 0) ? 0 : requestOf[from].cycle;

        _pay(asset, address(this), to, assets);
        emit Withdraw(msg.sender, to, from, assets, shares);
    }

    /**
     * Maintainance
     */

    /// @inheritdoc IRecyclerVaultV1Actions
    function give(uint256 assets) external auth {
        IERC20(asset).approve(staking, assets);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function vote(IOnChainVoteL1.UserVotePayload calldata data) external auth {
        IOnChainVoteL1(onchainvote).vote(data);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) public auth {
        IRewards(rewards).claim(recipient, v, r, s);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function stake(uint256 assets) public auth {
        IStaking(staking).deposit(assets);
    }

    function withdrawAndMigrate(address pool) external auth {
        ITokeMigrationPool(pool).withdrawAndMigrate();
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function cache() public auth {
        _cache();
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function rollover(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint32 deadline_
    ) external auth {
        // cache first as rewards should not be included in the slippage when depositing
        cache();
        claim(recipient, v, r, s);
        stake(_balanceOf(asset, address(this)));
        deadline = deadline_;
        emit SetDeadline(deadline);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function withdrawAll() external auth {
        (uint256 lastCycle, uint256 lockCycle, uint256 cycleAssets) = _withdrawStatus();
        _withdrawAll(lastCycle, lockCycle, cycleAssets);
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function status() external view returns (bool) {
        if (deadline < block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * Internal maintainance
     */

    function _deposit(uint256 assets) internal {
        IStaking(staking).deposit(assets);
    }

    function _requestWithdrawal(uint256 assets) internal {
        IStaking(staking).requestWithdrawal(assets, 0);
    }
    
    function _cycle() internal view returns (uint256) {
        return IManager(manager).getCurrentCycleIndex();
    }

    function _cache() internal {
        uint256 cycle_ = _cycle();

        if (cycle < cycle_) {
            totalSupplyCache = totalSupply;
            totalAssetsCache = totalAssets();
            cycle = cycle_;
            emit SetCycle(cycle);
            emit Cached(msg.sender, cycle, totalSupplyCache, totalAssetsCache);
        }
    }

    function _withdrawStatus() internal view returns (uint256, uint256, uint256) {
        (uint256 lockCycle, uint256 requestedAssets) =
            IStaking(staking).withdrawalRequestsByIndex(address(this), 0);
        return (IManager(manager).getCurrentCycleIndex(), lockCycle, requestedAssets);
    }

    function _withdrawAll(uint256 cycleNow, uint256 cycleLock, uint256 withdrawable) internal {
        if (cycleLock <= cycleNow && 0 < withdrawable) {
            // remove shares from `totalSupply` here because staking `balanceOf` only decreases
            // after calling `withdraw`
            totalSupply -= buffer;
            delete buffer;
            // withdraw tokens from staking, which also decreases this contract's `balanceOf`
            IStaking(staking).withdraw(withdrawable);
        }
    }

    /**
     * Internal helpers
     */

    /// @notice Helper function for transferring tokens.
    function _pay(address token, address from, address to, uint256 amount) internal {
        if (from == address(this))
            token.safeTransfer(to, amount);
        else
            token.safeTransferFrom(from, to, amount);
    }

    /// @notice Returns the block timestamp casted to `uint32`.
    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }

    /// @notice The balance of a token for this contract.
    function _balanceOf(address token, address account) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, account)
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }

    /// @notice Helper approve function.
    function _approve(address owner, address spender, uint256 coins) internal {
        allowance[owner][spender] = coins;
        emit Approval(owner, spender, coins);
    }

    /// @notice Decreases allowance - useful for burning, exiting, etc.
    function _decreaseAllowance(address from, uint256 coins) internal {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max) {
                _approve(from, msg.sender, allowed - coins);
            }
        }
    }

    /// @dev Important to authorize the upgrades.
    function _authorizeUpgrade(address newImplementation) internal override auth {}
}
