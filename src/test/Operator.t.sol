// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../interfaces/external/IRewards.sol";
import "../Recycler.sol";
import "../Operator.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

// An example payload for cycle 181 (cycle 181 is a "payout cycle").
// [1]: 0x8e47d82d78063d4fd8051cfc407f68e6c8d00f27 (`rewardSigner`)
// [2]: https://ipfs.tokemaklabs.xyz/ipfs/QmdxgHu5n1RdQRbrhJRqxpgBdihi5PAba5MRtYJcvstXDz/0x9e0bce7ec474b481492610eb9dd5d69eb03718d5.json
// {
//   "payload": {
//     "wallet": "0x9e0bce7ec474b481492610eb9dd5d69eb03718d5",
//     "cycle": 181,
//     "amount": "258852865328576216",
//     "chainId": 1
//   },
//   "signature": {
//     "v": 27,
//     "r": "0xfcc7966c1bce8adc98e979cd05bd2934f9a0127b70424162a31f86d822edbe85",
//     "s": "0x3960c804b83eb24f2354e992989da425d88100ec3e1f2861d1aff24278415ef5",
//     "msg": "0xfcc7966c1bce8adc98e979cd05bd2934f9a0127b70424162a31f86d822edbe853960c804b83eb24f2354e992989da425d88100ec3e1f2861d1aff24278415ef51b"
//   },
//   "summary": {
//     "cycleTotal": "4499603867566001",
//     "breakdown": [
//       {
//         "description": "LUSD",
//         "amount": "57856794254294"
//       },
//       {
//         "description": "FRAX",
//         "amount": "39770114125904"
//       },
//       {
//         "description": "TOKE",
//         "amount": "0"
//       },
//       ...
//     ]
//   }
// }

library KeyPair {
    address public constant publicKey = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract User {}

contract OperatorTest is DSTest, Vm, Utilities {
    Recycler public recycler;
    Operator public operator;

    User public user0;

    function setUp() public {
        recycler = new Recycler(address(tokeVotePool), 0);
        operator = new Operator(
            address(recycler),
            address(toke),
            address(tokeVotePool),
            address(onchainvote),
            address(rewards)
        );

        user0 = new User();

        recycler.allow(address(operator));
    }

    function testConstructor() public {
        assertEq(operator.recycler(), address(recycler));
    }

    /**
     * `set*`
     */

    function testSet() public {
        operator.setFeeTo(address(user0));
        assertEq(operator.feeTo(), address(user0));

        assertEq(operator.fee(), 100);
        operator.setFee(0);
        assertEq(operator.fee(), 0);

        operator.setReactorKey(bytes32(0), true);
        assertEq(operator.reactorKeys(bytes32(0)), true);
    }

    /**
     * `rollover`
     */

    // should rollover from epoch 1 to epoch 2
    // (because epoch 0 has no real rollover to epoch 1)
    function testRollover() public {
        realloc_reward_signer(KeyPair.publicKey);
        // before - create epoch 1
        assertEq(recycler.cursor(), 0);
        recycler.next(uint32(block.timestamp));

        // rollover
        operator.prepare(1e18);
        (Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        operator.rollover(recipient, v, r, s, 1, uint32(block.timestamp + 100));

        // after
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);
        assertEq(recycler.epochAs(1).filled, true);
        assertEq(recycler.cursor(), 2);
        assertEq(recycler.epochAs(2).filled, false);
        assertEq(recycler.epochAs(2).deadline, uint32(block.timestamp + 100));
    }

    /**
     * `compound`
     */

    function testCompound() public {
        realloc_reward_signer(KeyPair.publicKey);

        Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        operator.prepare(type(uint256).max);

        // compound once
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);

        // compound one more time
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 3e18);
    }

    function testCompoundWithFee() public {
        realloc_reward_signer(KeyPair.publicKey);
        operator.setFeeTo(address(user0));

        Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        operator.prepare(type(uint256).max);

        // compound once
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 9e17 + 9e16);
        // check feeTo got the fee
        assertEq(toke.balanceOf(address(user0)), 1e16);

        // compound one more time
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 2e18 + 9e17 + 7e16);
        // check feeTo got the fee
        assertEq(toke.balanceOf(address(user0)), 3e16);
    }

    /**
     * `claim`
     */

    function testClaim() public {
        realloc_reward_signer(KeyPair.publicKey);

        (Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);

        assertEq(toke.balanceOf(address(recycler)), 0);
        operator.claim(recipient, v, r, s);
        assertEq(toke.balanceOf(address(recycler)), 1e18);
    }

    function testClaimTwice() public {
        realloc_reward_signer(KeyPair.publicKey);

        Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // claim again, w/ 1e18
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        operator.claim(recipient, v, r, s);

        // claim again, w/ 3e18
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        operator.claim(recipient, v, r, s);

        // NOTE: the claimable amount is cumulative, so final amount should be 3e18
        assertEq(toke.balanceOf(address(recycler)), 3e18);
    }

    function testClaimWithFee() public {
        realloc_reward_signer(KeyPair.publicKey);
        operator.setFeeTo(address(user0));
        operator.setFee(1000); // 10%

        (Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);

        assertEq(toke.balanceOf(address(recycler)), 0);
        operator.claim(recipient, v, r, s);
        assertEq(toke.balanceOf(address(recycler)), 9e17);
        assertEq(toke.balanceOf(address(user0)), 1e17);
    }

    /**
     * `deposit`
     */

    function testDeposit() public {
        realloc_toke(address(recycler), 1e18);

        operator.prepare(1e18);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 0);
        operator.deposit(1e18);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);
    }

    function testDepositNoAllowanceError() public {
        realloc_toke(address(recycler), 1e18);

        expectRevert("ERC20: transfer amount exceeds allowance");
        operator.deposit(1e18);
    }

    function testDepositUnauthorized() public {
        realloc_toke(address(recycler), 1e18);

        operator.prepare(1e18);
        startPrank(address(user0));
        expectRevert("Denied");
        operator.deposit(1e18);
        stopPrank();
    }

    /**
     * `prepare`
     */

     function testPrepare() public {
        assertEq(toke.allowance(address(recycler), address(tokeVotePool)), 0);
        operator.prepare(type(uint256).max);
        assertEq(toke.allowance(address(recycler), address(tokeVotePool)), type(uint256).max);
    }

    // should revert because recycler has not allowed operator to use execute
    function testPrepareNoAuthToRecyclerError() public {
        recycler.deny(address(operator));
        expectRevert("Denied");
        operator.prepare(0);
    }

    // should revert because msg.sender is not auth:ed for operator
    function testPrepareUnauthorizedError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        operator.prepare(0);
    }

    /**
     * `vote`
     */

    function testVote() public {
        operator.setReactorKey(bytes32("tcr-default"), true);
        operator.setReactorKey(bytes32("fxs-default"), true);
        operator.setReactorKey(bytes32("eth-default"), true);

        UserVoteAllocationItem[] memory allocations = new UserVoteAllocationItem[](3);
        allocations[0] = UserVoteAllocationItem({ reactorKey: bytes32("tcr-default"), amount: 1e18 });
        allocations[1] = UserVoteAllocationItem({ reactorKey: bytes32("fxs-default"), amount: 3e18 });
        allocations[2] = UserVoteAllocationItem({ reactorKey: bytes32("eth-default"), amount: 2e18 });
        UserVotePayload memory data = UserVotePayload({
            account: address(recycler),
            voteSessionKey: 0x00000000000000000000000000000000000000000000000000000000000000ba,
            nonce: 0,
            chainId: uint256(137),
            totalVotes: 6e18,
            allocations: allocations
        });

        operator.vote(data);
    }
}
