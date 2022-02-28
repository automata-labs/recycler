// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { UUPSUpgradeable as ERC1967Implementation } from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IManager } from "./interfaces/external/IManager.sol";
import { IOnChainVoteL1 } from "./interfaces/external/IOnChainVoteL1.sol";
import { IRewards } from "./interfaces/external/IRewards.sol";
import { IStaking } from "./interfaces/external/IStaking.sol";
import { IRecyclerVaultV1 } from "./interfaces/v1/IRecyclerVaultV1.sol";
import { IRecyclerVaultV1Actions } from "./interfaces/v1/IRecyclerVaultV1Actions.sol";
import { IRecyclerVaultV1StateDerived } from "./interfaces/v1/IRecyclerVaultV1StateDerived.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { Request } from "./libraries/data/Request.sol";
import { Cast } from "./libraries/Cast.sol";
import { SafeTransfer } from "./libraries/SafeTransfer.sol";
import { RecyclerStorageV1 } from "./RecyclerStorageV1.sol";

contract RecyclerVaultV1 is ERC1967Implementation, RecyclerStorageV1 {
    using Cast for uint256;
    using SafeTransfer for address;

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
    }

    /**
     * ERC-20
     */

    function name() public pure returns (string memory) {
        return "(Re)cycler Staked Tokemak";
    }

    function symbol() external pure returns (string memory) {
        return "(re)TOKE";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert("Transfer not supported");
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert("Transfer not supported");
    }

    function approve(address spender, uint256 coins) external returns (bool) {
        _approve(msg.sender, spender, coins);

        return true;
    }

    /**
     * ERC-4626
     */
    
    function totalAssets() public view returns (uint256) {
        return IERC20(staking).balanceOf(address(this));
    }

    function assetsOf(address account) external view returns (uint256) {
        return convertToAssets(balanceOf[account]);
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint256 _totalAssets = totalAssets();

        if (_totalAssets > 0) {
            uint256 result = assets * totalSupply / _totalAssets;
            shares = (result == 0) ? assets : result;
        } else {
            shares = assets;
        }
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        if (totalSupply > 0)
            assets = (shares * (totalAssets())) / totalSupply;
        else
            assets = 0;
    }

    function maxDeposit(address) external view returns (uint256 maxAssets) {
        return capacity - totalAssets();
    }

    function maxRequest(address account) external view returns (uint256) {
        return convertToAssets(balanceOf[account]);
    }

    function maxWithdraw(address account) external view returns (uint256) {
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();

        if (requestOf[account].cycle <= cycleNow)
            return requestOf[account].assets;
        else
            return 0;
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        uint256 _totalAssets = totalAssets();

        if (_totalAssets > 0) {
            uint256 addend = _totalAssets * rate / UNIT_RATE;
            uint256 result = assets * totalSupply / (_totalAssets + addend);
            shares = (result == 0) ? assets : result;
        } else {
            shares = assets;
        }
    }

    function previewRequest(uint256 assets) public view returns (uint256 shares) {
        shares = convertToShares(assets);
    }

    function previewWithdraw(uint256) public pure returns (uint256 shares) {
        shares = 0;
    }

    function deposit(uint256 assets, address to) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient deposit");
        require(assets + _balanceOf(staking, address(this)) <= capacity, "Capacity overflow");
        require(block.timestamp <= deadline, "Deadline");

        shares = previewDeposit(assets);
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _deposit(assets);
        totalSupply += shares;
        balanceOf[to] += shares;
    }

    function request(uint256 assets, address from) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient request");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(cycleLock == cycleNow + 2 || cycleLock <= cycleNow, "Vault locked");
        require(requestOf[from].cycle == 0 || requestOf[from].cycle == cycleNow, "Withdrawal processing");

        shares = previewRequest(assets);
        _decreaseAllowance(from, shares);
        _withdrawAll(cycleNow);

        // vault effects
        cycleLock = cycleNow + 2;
        buffer += shares;
        // user effects
        balanceOf[from] -= shares;
        requestOf[from].cycle = (cycleNow + 2).u32();
        requestOf[from].assets += assets.u224();

        _requestWithdrawal(assets);
    }

    function withdraw(uint256 assets, address to, address from) external playback lock returns (uint256 shares) {
        require(assets > 0, "Insufficient withdrawable");
        uint256 cycleNow = IManager(manager).getCurrentCycleIndex();
        require(requestOf[from].cycle <= cycleNow, "Withdraw not matured");

        shares = 0;
        _decreaseAllowance(from, shares);
        _withdrawAll(cycleNow);

        requestOf[from].assets -= assets.u224();
        requestOf[from].cycle = (requestOf[from].assets == 0) ? 0 : requestOf[from].cycle;

        asset.safeTransfer(to, assets);
    }

    /**
     * Maintainance
     */

    function give(uint256 assets) external auth {
        IERC20(asset).approve(staking, assets);
    }

    function vote(IOnChainVoteL1.UserVotePayload calldata data) external auth {
        IOnChainVoteL1(onchainvote).vote(data);
    }

    function claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) public auth {
        IRewards(rewards).claim(recipient, v, r, s);
    }

    function stake(uint256 assets) public auth {
        IStaking(staking).deposit(assets);
    }

    function rollover(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint32 deadline_
    ) external auth {
        claim(recipient, v, r, s);
        stake(_balanceOf(asset, address(this)));
        deadline = deadline_;
        emit SetDeadline(deadline);
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

    function _withdrawAll(uint256 currentCycle) internal returns (uint256 assets) {
        uint256 cycle;
        (cycle, assets) = IStaking(staking).withdrawalRequestsByIndex(address(this), 0);

        if (currentCycle >= cycle && assets > 0) {
            // remove shares from `totalSupply` here because staking `balanceOf` only decreases
            // after calling `withdraw`
            totalSupply -= buffer;
            delete buffer;
            // withdraw tokens from staking, which also decreases this contract's `balanceOf`
            IStaking(staking).withdraw(assets);
        }
    }

    /**
     * Internal helpers
     */

    /// @notice Helper approve function.
    function _approve(address owner, address spender, uint256 coins) internal {
        allowance[owner][spender] = coins;
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

    /// @notice The balance of a token for this contract.
    function _balanceOf(address token, address account) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, account)
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }

    /// @notice Returns the block timestamp casted to `uint32`.
    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }

    /// @dev Important to authorize the upgrades.
    function _authorizeUpgrade(address newImplementation) internal override auth {}
}
