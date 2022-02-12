// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// import "./interfaces/external/IOnChainVoteL1.sol";
// import "./interfaces/external/IRewards.sol";
// import "./interfaces/external/IRewardsHash.sol";
// import "./interfaces/external/ITokeVotePool.sol";
// import "./interfaces/IOperator.sol";
// import "./interfaces/IRecycler.sol";
// import "./libraries/external/Tokemak.sol";
// import "./libraries/Auth.sol";

// /// @title Operator
// contract Operator is IOperator, Auth {
//     /// @notice Emitted when the fee to is set.
//     event SetFeeTo(address feeTo);
//     /// @notice Emitted when the fee is set.
//     event SetFee(uint256 fee);
//     /// @notice Emitted when a reactor key is set.
//     event SetReactorKey(bytes32 reactorKey, bool value);

//     /// @notice Throws when the fee is set too high.
//     error InvalidFee();
//     /// @notice Throws when voting on an invalid reactor key.
//     error InvalidReactorKey(bytes32 reactorKey);

//     /// @notice The max fee that can be set.
//     uint256 internal constant MAX_FEE = 1e4;

//     /// @inheritdoc IOperator
//     address public immutable recycler;
//     /// @inheritdoc IOperator
//     address public immutable underlying;
//     /// @inheritdoc IOperator
//     address public immutable derivative;
//     /// @inheritdoc IOperator
//     address public immutable onchainvote;
//     /// @inheritdoc IOperator
//     address public immutable rewards;

//     /// @inheritdoc IOperator
//     address public feeTo;
//     /// @inheritdoc IOperator
//     uint256 public fee;
//     /// @inheritdoc IOperator
//     mapping(bytes32 => bool) public reactorKeys;

//     constructor(
//         address recycler_,
//         address underlying_,
//         address derivative_,
//         address onchainvote_,
//         address rewards_
//     ) {
//         recycler = recycler_;
//         underlying = underlying_;
//         derivative = derivative_;
//         onchainvote = onchainvote_;
//         rewards = rewards_;

//         fee = 100; // 1%
//     }

//     /// @inheritdoc IOperator
//     function setFeeTo(address feeTo_)
//         external
//         auth
//     {
//         feeTo = feeTo_;
//         emit SetFeeTo(feeTo);
//     }

//     /// @inheritdoc IOperator
//     function setFee(uint256 fee_)
//         external
//         auth
//     {
//         if (fee_ > MAX_FEE)
//             revert InvalidFee();

//         fee = fee_;
//         emit SetFee(fee_);
//     }

//     /// @inheritdoc IOperator
//     function setReactorKey(bytes32 reactorKey, bool value)
//         external
//         auth
//     {
//         reactorKeys[reactorKey] = value;
//     }

//     /// @inheritdoc IOperator
//     function rollover(
//         Recipient memory recipient,
//         uint8 v,
//         bytes32 r,
//         bytes32 s,
//         uint256 epoch,
//         uint32 deadline
//     )
//         external
//         auth
//     {
//         compound(recipient, v, r, s);

//         if (epoch != 0)
//             IRecycler(recycler).fill(epoch);

//         if (deadline != 0)
//             IRecycler(recycler).next(deadline);
//     }

//     /// @inheritdoc IOperator
//     function compound(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
//         public
//         auth
//     {
//         (uint256 claimed, ) = claim(recipient, v, r, s);
//         deposit(claimed);
//     }

//     /// @inheritdoc IOperator
//     function claim(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
//         public
//         auth
//         returns (uint256 claimed, uint256 fees)
//     {
//         claimed = IRewards(rewards).getClaimableAmount(Recipient({
//             chainId: recipient.chainId,
//             cycle: recipient.cycle,
//             wallet: recipient.wallet,
//             amount: recipient.amount
//         }));

//         address[] memory targets = new address[](1);
//         bytes[] memory datas = new bytes[](1);
//         targets[0] = rewards;
//         datas[0] = abi.encodeWithSelector(IRewards.claim.selector, recipient, v, r, s);
//         IRecycler(recycler).execute(targets, datas);

//         if (fee > 0 && feeTo != address(0)) {
//             fees = (claimed * fee) / MAX_FEE;
//             claimed -= fees;

//             targets = new address[](1);
//             datas = new bytes[](1);
//             targets[0] = underlying;
//             datas[0] = abi.encodeWithSelector(IERC20.transfer.selector, feeTo, fees);
//             IRecycler(recycler).execute(targets, datas);
//         }
//     }

//     /// @inheritdoc IOperator
//     function deposit(uint256 amount)
//         public
//         auth
//     {
//         address[] memory targets = new address[](1);
//         bytes[] memory datas = new bytes[](1);
//         targets[0] = derivative;
//         datas[0] = abi.encodeWithSelector(ITokeVotePool.deposit.selector, amount);

//         IRecycler(recycler).execute(targets, datas);
//     }

//     /// @inheritdoc IOperator
//     function prepare(uint256 amount)
//         external
//         auth
//     {
//         address[] memory targets = new address[](1);
//         bytes[] memory datas = new bytes[](1);
//         targets[0] = underlying;
//         datas[0] = abi.encodeWithSelector(IERC20.approve.selector, derivative, amount);

//         IRecycler(recycler).execute(targets, datas);
//     }

//     /// @inheritdoc IOperator
//     function vote(UserVotePayload calldata data)
//         external
//         auth
//     {
//         for (uint256 i = 0; i < data.allocations.length; i++) {
//             if (!reactorKeys[data.allocations[i].reactorKey]) {
//                 revert InvalidReactorKey(data.allocations[i].reactorKey);
//             }
//         }

//         address[] memory targets = new address[](1);
//         bytes[] memory datas = new bytes[](1);
//         targets[0] = onchainvote;
//         datas[0] = abi.encodeWithSelector(IOnChainVoteL1.vote.selector, data);

//         IRecycler(recycler).execute(targets, datas);
//     }
// }
