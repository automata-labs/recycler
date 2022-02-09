// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./libraries/external/Tokemak.sol";
import "./libraries/Auth.sol";
import "./interfaces/external/IOnChainVoteL1.sol";
import "./interfaces/external/IRewards.sol";
import "./interfaces/external/IRewardsHash.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/IRecycler.sol";

contract Operator is Auth {
    /// @notice Emitted when a reactor key is set.
    event SetReactorKey(bytes32 reactorKey, bool value);

    /// @notice Throws when voting on an invalid reactor key.
    error InvalidReactorKey(bytes32 reactorKey);

    /// @notice The core reactor contract that holds the assets.
    address public immutable recycler;
    /// @notice The underlying TOKE token.
    address public immutable underlying;
    /// @notice The derivative tTOKE token.
    address public immutable derivative;
    /// @notice The Tokemak voting contract.
    address public immutable onchainvote;
    /// @notice The Tokemak rewards contract.
    address public immutable rewards;

    /// @notice Accepted reactor keys that this contract can vote with.
    mapping(bytes32 => bool) public reactorKeys;

    constructor(
        address recycler_,
        address underlying_,
        address derivative_,
        address onchainvote_,
        address rewards_
    ) {
        recycler = recycler_;
        underlying = underlying_;
        derivative = derivative_;
        onchainvote = onchainvote_;
        rewards = rewards_;
    }

    function setReactorKey(bytes32 reactorKey, bool value) external {
        reactorKeys[reactorKey] = value;
    }

    /// @notice Claims TOKE, deposits TOKE for tTOKE, fills an `epoch` and creates an new epoch with
    /// the a `deadline` - all in one transaction.
    /// @dev A convenience function for the admin.
    function rollover(
        Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 epoch,
        uint32 deadline
    )
        external
        auth
    {
        compound(recipient, v, r, s);

        if (epoch != 0)
            IRecycler(recycler).fill(epoch);

        if (deadline != 0)
            IRecycler(recycler).next(deadline);
    }

    /// @notice Claims- and stakes the token rewards to compound the assets.
    function compound(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        public
        auth
    {
        uint256 claimable = IRewards(rewards).getClaimableAmount(Recipient({
            chainId: recipient.chainId,
            cycle: recipient.cycle,
            wallet: recipient.wallet,
            amount: recipient.amount
        }));

        claim(recipient, v, r, s);
        deposit(claimable);
    }

    /// @notice Deposit TOKE for Recycler.
    function claim(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        public
        auth
    {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = rewards;
        datas[0] = abi.encodeWithSelector(IRewards.claim.selector, recipient, v, r, s);

        IRecycler(recycler).execute(targets, datas);
    }

    /// @notice Deposit TOKE for tTOKE for the Recycler.
    function deposit(uint256 amount)
        public
        auth
    {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = derivative;
        datas[0] = abi.encodeWithSelector(ITokeVotePool.deposit.selector, amount);

        IRecycler(recycler).execute(targets, datas);
    }

    /// @notice Approves the tTOKE to pull TOKE tokens from this contract.
    /// @dev This is required because the tTOKE contract pulls fund using allowance to stake TOKE.
    /// If not called before e.g. `deposit`, `compound` or `posteriori`, then the call will revert.
    function prepare(uint256 amount)
        external
        auth
    {
        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = underlying;
        datas[0] = abi.encodeWithSelector(IERC20.approve.selector, derivative, amount);

        IRecycler(recycler).execute(targets, datas);
    }

    /// @notice Vote on Tokemak reactors using the Recycler.
    /// @dev Each reactor key will be checked against a mapping to see if it's valid.
    function vote(UserVotePayload calldata data)
        external
        auth
    {
        for (uint256 i = 0; i < data.allocations.length; i++) {
            if (!reactorKeys[data.allocations[i].reactorKey]) {
                revert InvalidReactorKey(data.allocations[i].reactorKey);
            }
        }

        address[] memory targets = new address[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = onchainvote;
        datas[0] = abi.encodeWithSelector(IOnChainVoteL1.vote.selector, data);

        IRecycler(recycler).execute(targets, datas);
    }
}