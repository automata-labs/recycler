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
import { IRecyclerVaultV0 } from "./interfaces/v0/IRecyclerVaultV0.sol";
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
    ) external auth {
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

        give(type(uint256).max);
    }

    function migrate() external auth {
        IRecyclerVaultV0 recyclerV0 = IRecyclerVaultV0(0x707059006C9936d13064F15FA963a528eC98A055);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);

        // transfer in all tTOKE
        uint256 balance = IERC20(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930).balanceOf(address(recyclerV0));
        targets[0] = 0xa760e26aA76747020171fCF8BdA108dFdE8Eb930;
        values[0] = 0;
        datas[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), balance);
        recyclerV0.execute(targets, values, datas);

        // unwrap tTOKE into TOKE and stake
        ITokeMigrationPool(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930).withdrawAndMigrate();

        // distribute shares to accounts
        totalSupply +=
            42000000000000000000 +
            5000000000000000000 +
            30562988479619097434 +
            40606267960675771288 +
            81396694486252784289 +
            5500000000000000000 +
            40665731046031782725 +
            5000000000000000000 +
            251655604857061830000 +
            44191937774658306928 +
            6490989577432604977 +
            10596603336256432549;
        balanceOf[0xf8cdF370f132dEb1eb98600886160ed027707919] = 42000000000000000000;
        balanceOf[0xaB281a90645Cb13E440D4d12E7aA8F1e74ae8459] = 5000000000000000000;
        balanceOf[0xD20d4989F32C31d296673C141Cb02477DE7ADc5e] = 30562988479619097434;
        balanceOf[0xc244dD4f34A0d5EDc7aF3565b2ab72dD76Ef78e9] = 40606267960675771288;
        balanceOf[0x2809D5D8f8771c9278DdF0A2D452501ACe7d790A] = 81396694486252784289;
        balanceOf[0x5f73a24771940b8c80b3570694072f606DF913cc] = 5500000000000000000;
        balanceOf[0xC8ecE128e77dFe3a3Bbd2c7d54101f2238F8b611] = 40665731046031782725;
        balanceOf[0x38430336153468dcf36Af5cea7D6bc472425633A] = 5000000000000000000;
        balanceOf[0x5f7CA8a9775fF2A7008dDA02683d2aE2BD3671a9] = 251655604857061830000;
        balanceOf[0xAB12253171A0d73df64B115cD43Fe0A32Feb9dAA] = 44191937774658306928;
        balanceOf[0xbF133C1763c0751494CE440300fCd6b8c4e80D83] = 6490989577432604977;
        balanceOf[0xA908Af6fD5E61360e24FcA8C8fa6755786409cCe] = 10596603336256432549;
        emit Transfer(address(0), 0xf8cdF370f132dEb1eb98600886160ed027707919, 42000000000000000000);
        emit Transfer(address(0), 0xaB281a90645Cb13E440D4d12E7aA8F1e74ae8459, 5000000000000000000);
        emit Transfer(address(0), 0xD20d4989F32C31d296673C141Cb02477DE7ADc5e, 30562988479619097434);
        emit Transfer(address(0), 0xc244dD4f34A0d5EDc7aF3565b2ab72dD76Ef78e9, 40606267960675771288);
        emit Transfer(address(0), 0x2809D5D8f8771c9278DdF0A2D452501ACe7d790A, 81396694486252784289);
        emit Transfer(address(0), 0x5f73a24771940b8c80b3570694072f606DF913cc, 5500000000000000000);
        emit Transfer(address(0), 0xC8ecE128e77dFe3a3Bbd2c7d54101f2238F8b611, 40665731046031782725);
        emit Transfer(address(0), 0x38430336153468dcf36Af5cea7D6bc472425633A, 5000000000000000000);
        emit Transfer(address(0), 0x5f7CA8a9775fF2A7008dDA02683d2aE2BD3671a9, 251655604857061830000);
        emit Transfer(address(0), 0xAB12253171A0d73df64B115cD43Fe0A32Feb9dAA, 44191937774658306928);
        emit Transfer(address(0), 0xbF133C1763c0751494CE440300fCd6b8c4e80D83, 6490989577432604977);
        emit Transfer(address(0), 0xA908Af6fD5E61360e24FcA8C8fa6755786409cCe, 10596603336256432549);

        // claim TOKE on the recycler
        targets[0] = rewards;
        values[0] = 0;
        datas[0] = abi.encodeWithSignature(
            "claim((uint256,uint256,address,uint256),uint8,bytes32,bytes32)",
            IRewards.Recipient({
                chainId: uint256(1),
                cycle: uint256(200),
                wallet: address(0x707059006C9936d13064F15FA963a528eC98A055),
                amount: uint256(3063292820952196327)
            }),
            uint8(27),
            bytes32(0x05c8f5b4eb854c339bc62195e4c71d20c7227f1f3b9f66fc783ff77bc6d1e28c),
            bytes32(0x4e5fd565df9d3f3ace0f43d5abbc4cb87a093877ef188d7846de43132ddd334b)
        );
        recyclerV0.execute(targets, values, datas);

        // transfer TOKE into this contract
        balance = IERC20(asset).balanceOf(address(recyclerV0));
        targets[0] = asset;
        values[0] = 0;
        datas[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), balance);
        recyclerV0.execute(targets, values, datas);

        // stake the TOKE on this contract
        _deposit(balance);

        // update the cache to latest.
        // should only be needed to be set manually once in this migrate.
        cache();
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
    /// @dev This function calculates based on cached values of `totalSupply` and `totalAssets`.
    /// The cached values 
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
        require(cycle == _cycle(), "Cycle not synchronized");
        require((shares = previewDeposit(assets)) > 0, "Insufficient conversion");
        _pay(asset, msg.sender, address(this), assets);

        totalSupply += shares;
        balanceOf[to] += shares;

        _deposit(assets);
        emit Transfer(address(0), to, shares);
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
        emit Transfer(from, address(0), shares);
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
    function give(uint256 assets) public auth {
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

    /// @inheritdoc IRecyclerVaultV1Actions
    function cache() public auth {
        totalSupplyCache = totalSupply;
        totalAssetsCache = totalAssets();
        emit Cached(msg.sender, cycle, totalSupplyCache, totalAssetsCache);
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function rollover() public auth {
        cache();
        cycle = _cycle();
        emit SetCycle(cycle);
    }

    function compound(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external auth {
        claim(recipient, v, r, s);
        stake(_balanceOf(asset, address(this)));
        rollover();
    }

    /// @inheritdoc IRecyclerVaultV1Actions
    function withdrawAll() external auth {
        (uint256 lastCycle, uint256 lockCycle, uint256 cycleAssets) = _withdrawStatus();
        _withdrawAll(lastCycle, lockCycle, cycleAssets);
    }

    /// @inheritdoc IRecyclerVaultV1StateDerived
    function status() external view returns (bool) {
        return (cycle != _cycle());
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
