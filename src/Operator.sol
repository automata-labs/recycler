// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libraries/external/Tokemak.sol";
import "./libraries/Auth.sol";
import "./interfaces/external/IOnChainVoteL1.sol";
import "./interfaces/external/IRewards.sol";
import "./interfaces/external/IRewardsHash.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/IOperator.sol";
import "./interfaces/IReactor.sol";

/// @title Operator
contract Operator is IOperator, Auth {
    /// @inheritdoc IOperator
    address public immutable reactor;
    /// @inheritdoc IOperator
    address public immutable underlying;
    /// @inheritdoc IOperator
    address public immutable derivative;
    /// @inheritdoc IOperator
    address public immutable onchainvote;
    /// @inheritdoc IOperator
    address public immutable rewards;
    /// @inheritdoc IOperator
    address public immutable rewardsHash;

    constructor(
        address reactor_,
        address underlying_,
        address derivative_,
        address onchainvote_,
        address rewards_,
        address rewardsHash_
    ) {
        reactor = reactor_;
        underlying = underlying_;
        derivative = derivative_;
        onchainvote = onchainvote_;
        rewards = rewards_;
        rewardsHash = rewardsHash_;
    }

    /// @inheritdoc IOperator
    function prepare(uint256 amount)
        external
        auth
    {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = underlying;
        datas[0] = abi.encodeWithSelector(IERC20.approve.selector, derivative, amount);

        IReactor(reactor).execute(targets, datas);
    }

    /// @inheritdoc IOperator
    function compound(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        external
        auth
    {
        uint256 claimable = IRewards(rewards).getClaimableAmount(Recipient({
            chainId: recipient.chainId,
            cycle: recipient.cycle,
            wallet: recipient.wallet,
            amount: recipient.amount
        }));

        _claim(recipient, v, r, s);
        _deposit(claimable);
    }

    /// @inheritdoc IOperator
    function vote(UserVotePayload calldata data)
        external
        auth
    {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = onchainvote;
        datas[0] = abi.encodeWithSelector(IOnChainVoteL1.vote.selector, data);

        IReactor(reactor).execute(targets, datas);
    }

    /// @inheritdoc IOperator
    function claim(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        external
        auth
    {
        _claim(recipient, v, r, s);
    }

    /// @inheritdoc IOperator
    function deposit(uint256 amount)
        external
        auth
    {
        _deposit(amount);
    }

    /**
     * Internal
     */

    function _claim(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) internal {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = rewards;
        datas[0] = abi.encodeWithSelector(IRewards.claim.selector, recipient, v, r, s);

        IReactor(reactor).execute(targets, datas);
    }

    function _deposit(uint256 amount) internal {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = derivative;
        datas[0] = abi.encodeWithSelector(ITokeVotePool.deposit.selector, amount);

        IReactor(reactor).execute(targets, datas);
    }
}
