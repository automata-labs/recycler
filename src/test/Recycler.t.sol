// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/external/IOnChainVoteL1.sol";
import "../interfaces/IRecycler.sol";
import "../libraries/SafeTransfer.sol";
import "../Recycler.sol";
import "../RecyclerManager.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract User is Vm, Utilities {
    RecyclerManager public manager;

    constructor(RecyclerManager manager_) {
        manager = manager_;
    }

    function mint(uint256 amount) public {
        startPrank(address(this));
        realloc_ttoke(address(this), amount);
        tokeVotePool.approve(address(manager), type(uint256).max);
        manager.mint(address(this), amount);
        stopPrank();
    }
}

library KeyPair {
    address public constant publicKey = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract RecyclerTest is DSTest, Vm, Utilities {
    Recycler public recycler;
    RecyclerManager public manager;

    User public user0;
    User public user1;
    User public user2;

    function _deadline(uint32 extra) internal view returns (uint32) {
        return uint32(block.timestamp) + extra;
    }

    function setUp() public {
        recycler = new Recycler(
            address(toke),
            address(tokeVotePool),
            address(onchainvote),
            address(rewards),
            0
        );
        manager = new RecyclerManager(address(tokeVotePool), IRecycler(recycler));
        user0 = new User(manager);
        user1 = new User(manager);
        user2 = new User(manager);
    }

    function setUpBurn() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp + 1));
        manager.mint(address(this), 1e18);
        recycler.fill(1);
    }

    function testConstructor() public {
        assertEq(recycler.name(), "(Re)cycler Staked Tokemak");
        assertEq(recycler.symbol(), "(re)tTOKE");
        assertEq(recycler.decimals(), 18);
        assertEq(recycler.dust(), 0);
    }

    /**
     * `pause`
     */

    function testPause() public {
        recycler.pause(IRecycler.mint.selector);
        assertEq(recycler.paused(IRecycler.mint.selector), 1);
    }

    function testPauseUnauthorizedError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.pause(IRecycler.mint.selector);
        stopPrank();
    }

    /**
     * `set*`
     */
    
    function testSet() public {
        recycler.next(0);

        recycler.setDust(123e18);
        assertEq(recycler.dust(), 123e18);
        recycler.setCapacity(456e18);
        assertEq(recycler.capacity(), 456e18);
        recycler.setDeadline(1, uint32(block.timestamp));
        assertEq(recycler.epochAs(1).deadline, uint32(block.timestamp));

        recycler.setDust(0);
        assertEq(recycler.dust(), 0);
        recycler.setCapacity(0);
        assertEq(recycler.capacity(), 0);
        recycler.setDeadline(1, 0);
        assertEq(recycler.epochAs(1).deadline, 0);

        recycler.setFee(100); // 1%
        assertEq(recycler.fee(), 100);

        recycler.setMaintainer(address(user0));
        assertEq(recycler.maintainer(), address(user0));

        recycler.setKey(bytes32(0), true);
        assertEq(recycler.keys(bytes32(0)), true);
    }

    function testSetUnauthorizedError() public {
        recycler.next(0);

        startPrank(address(user0));
        expectRevert("Denied");
        recycler.setDust(0);
        expectRevert("Denied");
        recycler.setCapacity(0);
        expectRevert("Denied");
        recycler.setDeadline(1, 0);
        stopPrank();
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
        recycler.prepare(1e18);
        (IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        recycler.rollover(recipient, v, r, s, 1, uint32(block.timestamp + 100));

        // after
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);
        assertEq(recycler.epochAs(1).filled, true);
        assertEq(recycler.cursor(), 2);
        assertEq(recycler.epochAs(2).filled, false);
        assertEq(recycler.epochAs(2).deadline, uint32(block.timestamp + 100));
    }

    /**
     * `cycle`
     */

    function testCycle() public {
        realloc_reward_signer(KeyPair.publicKey);

        IRewards.Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        recycler.prepare(type(uint256).max);

        // compound once
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        recycler.cycle(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);

        // compound one more time
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        recycler.cycle(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 3e18);
    }

    function testCycleWithFee() public {
        realloc_reward_signer(KeyPair.publicKey);
        recycler.setMaintainer(address(user0));
        recycler.setFee(100);

        IRewards.Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        recycler.prepare(type(uint256).max);

        // compound once
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        recycler.cycle(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 9e17 + 9e16);
        // check maintainer got the fee
        assertEq(toke.balanceOf(address(user0)), 1e16);

        // compound one more time
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        recycler.cycle(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 2e18 + 9e17 + 7e16);
        // check maintainer got the fee
        assertEq(toke.balanceOf(address(user0)), 3e16);
    }

    /**
     * `claim`
     */

    function testClaim() public {
        realloc_reward_signer(KeyPair.publicKey);

        (IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);

        assertEq(toke.balanceOf(address(recycler)), 0);
        recycler.claim(recipient, v, r, s);
        assertEq(toke.balanceOf(address(recycler)), 1e18);
    }

    function testClaimTwice() public {
        realloc_reward_signer(KeyPair.publicKey);

        IRewards.Recipient memory recipient;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // claim again, w/ 1e18
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);
        recycler.claim(recipient, v, r, s);

        // claim again, w/ 3e18
        (recipient, v, r, s) = buildRecipient(1, 181, address(recycler), 3e18, KeyPair.privateKey);
        recycler.claim(recipient, v, r, s);

        // NOTE: the claimable amount is cumulative, so final amount should be 3e18
        assertEq(toke.balanceOf(address(recycler)), 3e18);
    }

    function testClaimWithFee() public {
        realloc_reward_signer(KeyPair.publicKey);
        recycler.setFee(1000); // 10%
        recycler.setMaintainer(address(user0));

        (IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) =
            buildRecipient(1, 181, address(recycler), 1e18, KeyPair.privateKey);

        assertEq(toke.balanceOf(address(recycler)), 0);
        recycler.claim(recipient, v, r, s);
        assertEq(toke.balanceOf(address(recycler)), 9e17);
        assertEq(toke.balanceOf(address(user0)), 1e17);
    }

    /**
     * `stake`
     */

    function testStake() public {
        realloc_toke(address(recycler), 1e18);

        recycler.prepare(1e18);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 0);
        recycler.stake(1e18);
        assertEq(tokeVotePool.balanceOf(address(recycler)), 1e18);
    }

    function testStakeNoAllowanceError() public {
        realloc_toke(address(recycler), 1e18);

        expectRevert("ERC20: transfer amount exceeds allowance");
        recycler.stake(1e18);
    }

    function testStakeUnauthorized() public {
        realloc_toke(address(recycler), 1e18);

        recycler.prepare(1e18);
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.stake(1e18);
        stopPrank();
    }

    /**
     * `prepare`
     */

     function testPrepare() public {
        assertEq(toke.allowance(address(recycler), address(tokeVotePool)), 0);
        recycler.prepare(type(uint256).max);
        assertEq(toke.allowance(address(recycler), address(tokeVotePool)), type(uint256).max);
    }

    // should revert because msg.sender is not auth:ed for recycler
    function testPrepareUnauthorizedError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.prepare(0);
    }

    /**
     * `vote`
     */

    function testVote() public {
        recycler.setKey(bytes32("tcr-default"), true);
        recycler.setKey(bytes32("fxs-default"), true);
        recycler.setKey(bytes32("eth-default"), true);

        IOnChainVoteL1.UserVoteAllocationItem[] memory allocations = new IOnChainVoteL1.UserVoteAllocationItem[](3);
        allocations[0] = IOnChainVoteL1.UserVoteAllocationItem({ reactorKey: bytes32("tcr-default"), amount: 1e18 });
        allocations[1] = IOnChainVoteL1.UserVoteAllocationItem({ reactorKey: bytes32("fxs-default"), amount: 3e18 });
        allocations[2] = IOnChainVoteL1.UserVoteAllocationItem({ reactorKey: bytes32("eth-default"), amount: 2e18 });
        IOnChainVoteL1.UserVotePayload memory data = IOnChainVoteL1.UserVotePayload({
            account: address(recycler),
            voteSessionKey: 0x00000000000000000000000000000000000000000000000000000000000000ba,
            nonce: 0,
            chainId: uint256(137),
            totalVotes: 6e18,
            allocations: allocations
        });

        recycler.vote(data);
    }

    /**
     * `next`
     */

    function testNext() public {
        uint32 deadline = uint32(block.timestamp + 1);

        assertEq(recycler.cursor(), 0);
        recycler.next(deadline);
        assertEq(recycler.cursor(), 1);

        // epoch: 0
        assertEq(recycler.epochAs(0).deadline, 0);
        assertEq(recycler.epochAs(0).amount, 0);
        assertEq(recycler.epochAs(0).shares, 0);
        assertEq(recycler.epochAs(0).filled, true);
        // epoch: 1
        assertEq(recycler.epochAs(1).deadline, deadline);
        assertEq(recycler.epochAs(1).amount, 0);
        assertEq(recycler.epochAs(1).shares, 0);
        assertEq(recycler.epochAs(1).filled, false);

        // go to next cursor and check and its epoch
        recycler.next(deadline + 1);
        assertEq(recycler.cursor(), 2);
        assertEq(recycler.epochAs(2).deadline, deadline + 1);

        // check that there are two unfilled epochs in a row
        assertEq(recycler.epochAs(1).filled, false);
        assertEq(recycler.epochAs(2).filled, false);
    }

    // try creating an epoch with past timestamp as deadline
    function testNextPast() public {
        recycler.next(1337);
        assertEq(recycler.cursor(), 1);
        assertEq(recycler.epochAs(1337).deadline, 0);
        assertEq(recycler.epochAs(1).amount, 0);
        assertEq(recycler.epochAs(1).shares, 0);
        assertEq(recycler.epochAs(1).filled, false);

        // make sure that it can be filled, otherwise soft-locked
        recycler.fill(1);
    }

    // try creating an epoch with zero timestamp as deadline
    function testNextZero() public {
        recycler.next(0);
        assertEq(recycler.cursor(), 1);
        assertEq(recycler.epochAs(1).deadline, 0);
        assertEq(recycler.epochAs(1).amount, 0);
        assertEq(recycler.epochAs(1).shares, 0);
        assertEq(recycler.epochAs(1).filled, false);

        // make sure that it can be filled, otherwise soft-locked
        recycler.fill(1);
    }

    function testNextUnauthorizedError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.next(0);
        stopPrank();
    }

    /**
     * `mint`
     */

    function testMint() public {
        recycler.next(uint32(block.timestamp + 1));

        // mint as a user
        user0.mint(1e18);
        // balance still zero bc epoch not filled
        assertEq(recycler.balanceOf(address(user0)), 0);

        // mint as this
        realloc_ttoke(address(this), 3e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        // mint only 2 of 3
        manager.mint(address(this), 2e18);
        // 1 remaining
        assertEq(tokeVotePool.balanceOf(address(this)), 1e18);
        // balance still zero bc epoch not filled
        assertEq(recycler.balanceOf(address(this)), 0);

        // fill should make balance show up
        recycler.fill(1);
        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.balanceOf(address(this)), 2e18);
    }

    // should mint multiple times on the same epoch
    // shouldn't make a difference if it's many small or one big tx
    function testMintMultipleDepositsOnSameEpoch() public {
        recycler.next(uint32(block.timestamp + 1));

        user0.mint(1e18);
        user0.mint(1e18);
        user0.mint(1e18);
        assertEq(recycler.balanceOf(address(user0)), 0);

        recycler.fill(1);
        assertEq(recycler.balanceOf(address(user0)), 3e18);
    }

    // should tick the buffer and then mint afterwards
    function testMintTickBufferIfFilled() public {
        recycler.next(uint32(block.timestamp + 1));

        user0.mint(1e18);
        warp(block.timestamp + 2);
        recycler.fill(1);

        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.sharesOf(address(user0)), 0);
        assertEq(recycler.bufferAs(address(user0)).epoch, 1);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // simulate compounding on the recycler...
        realloc_ttoke(address(recycler), 1e18);

        // should revert if next epoch hasn't started
        startPrank(address(user0));
        realloc_ttoke(address(user0), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(user0), 1e18);
        stopPrank();

        // go next after compounding
        recycler.next(uint32(block.timestamp + 1));
        // mint again with user to see that it ticks
        user0.mint(1e18);

        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        recycler.fill(2);
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1);

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18 + 5e17);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.bufferAs(address(user0)).epoch, 3);
        assertEq(recycler.bufferAs(address(user0)).amount, 1);

        recycler.fill(3);
        assertEq(recycler.balanceOf(address(user0)), 3e18 + 1);
    }

    // throw if admin has paused mint
    function testMintPausedError() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);

        recycler.pause(IRecycler.mint.selector);
        expectRevert("Paused");
        manager.mint(address(this), 1e18);
    }

    // throw when calling when only init:ed
    function testMintOnInitializedContractError() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(this), 1e18);
    }

    // throw when not enough coins were transferred
    function testMintInsufficientTransferError() public {
        recycler.next(_deadline(100));

        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert("SafeTransferFailed");
        manager.mint(address(this), 1e18);
    }

    // throw when deadline is in the past, but we've deposited to it in the past
    function testMintEpochExpiredWhenFilledError() public {
        recycler.next(_deadline(1));
        recycler.fill(1);

        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(this), 1e18);
    }

    // throw when deadline is in the past
    function testMintEpochExpiredWhenDeadlinePassedError() public {
        recycler.next(_deadline(100));
        // timetravel to when deadline is hit
        warp(_deadline(101));

        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(this), 1e18);
    }

    // throw when a user has deposited into a past epoch, and that epoch has not been filled.
    // if the user's buffer was empty, then it wouldn't matter when they deposited - all that'd be
    // needed would be that the current epoch is available for deposits.
    //
    // to prevent the error, the admin needs to the fill the previous epochs.
    function testMintPastBufferExistsButNotFilledError() public {
        recycler.next(_deadline(1));
        // deposit
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        manager.mint(address(this), 1e18);

        // go to next epochs and try deposit again, which should fail
        recycler.next(_deadline(2)); // time does not actually need to increase, but w/e
        recycler.next(_deadline(3));

        // throw error
        realloc_ttoke(address(this), 1e18);
        expectRevert(abi.encodeWithSignature("BufferExists()"));
        manager.mint(address(this), 1e18);
    }

    /**
     * `burn`
     */

    function testBurn() public {
        recycler.next(_deadline(1));
        user0.mint(1e18);
        recycler.fill(1);

        uint256 balance = recycler.balanceOf(address(user0));
        startPrank(address(user0));
        recycler.burn(address(user0), address(user0), balance);
        assertEq(tokeVotePool.balanceOf(address(user0)), balance);
        stopPrank();
    }

    // burn when the owner has approved enough to the spender/burner
    function testBurnUsingAllowance() public {
        recycler.next(_deadline(1));
        user0.mint(1e18);
        recycler.fill(1);

        startPrank(address(user0));
        recycler.approve(address(this), 1e18);
        stopPrank();

        recycler.burn(address(user0), address(user1), 1e18);
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(tokeVotePool.balanceOf(address(user1)), 1e18);
    }

    // throw if trying to burn another users shares without permissions
    // i.e. allowance underflows
    function testBurnWhenNotAllowedError() public {
        recycler.next(_deadline(1));
        user0.mint(1e18);
        recycler.fill(1);

        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.burn(address(user0), address(user1), 1e18);
    }

    /**
     * `fill`
     */

    // fills normally, without any excessive coins.
    // this means that coins <=> shares in this unit test.
    function testFill() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp + 1));
        manager.mint(address(this), 1e18);

        assertEq(recycler.totalSupply(), 1e18);
        assertEq(recycler.totalShares(), 0);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(recycler.sharesOf(address(this)), 0);
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
        assertEq(recycler.epochAs(1).deadline, uint32(block.timestamp + 1));
        assertEq(recycler.epochAs(1).amount, 1e18);
        assertEq(recycler.epochAs(1).shares, 0);
        assertEq(recycler.epochAs(1).filled, false);

        recycler.fill(1);

        assertEq(recycler.totalSupply(), 1e18);
        assertEq(recycler.totalShares(), 1e18); // +
        assertEq(recycler.balanceOf(address(this)), 1e18); // + balance should be defined now bc filled
        assertEq(recycler.sharesOf(address(this)), 0); // + shares zero bc not tick:ed
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
        assertEq(recycler.epochAs(1).deadline, uint32(block.timestamp + 1));
        assertEq(recycler.epochAs(1).amount, 1e18);
        assertEq(recycler.epochAs(1).shares, 1e18); // +
        assertEq(recycler.epochAs(1).filled, true); // +
    }

    // fill should never fail, even if deposited coins was zero
    // try filling multiple in a row
    function testFillZeroShares() public {
        recycler.next(uint32(block.timestamp + 1));
        recycler.fill(1);

        recycler.next(uint32(block.timestamp + 1));
        recycler.fill(2);

        recycler.next(uint32(block.timestamp + 1));
        recycler.fill(3);

        assertEq(recycler.epochAs(1).shares, 0); // +
        assertEq(recycler.epochAs(1).filled, true); // +
        assertEq(recycler.epochAs(2).shares, 0); // +
        assertEq(recycler.epochAs(2).filled, true); // +
        assertEq(recycler.epochAs(3).shares, 0); // +
        assertEq(recycler.epochAs(3).filled, true); // +
    }

    // should have an excessive amount of coins per share
    function testFillWithEarnedCoinsOnShares() public {
        recycler.next(_deadline(1));

        user0.mint(1e18);
        user1.mint(3e18);
        realloc_ttoke(address(recycler), 1e18);
        recycler.fill(1);

        assertEq(recycler.totalShares(), 4e18);
        assertEq(recycler.epochAs(1).amount, 4e18);
        assertEq(recycler.epochAs(1).shares, 4e18);
        assertEq(recycler.balanceOf(address(user0)), 1e18 + 25e16);
        assertEq(recycler.balanceOf(address(user1)), 3e18 + 75e16);

        recycler.poke(address(user0));
        recycler.poke(address(user1));
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.sharesOf(address(user1)), 3e18);

        // user2 joins mid-next epoch
        // user2 does not get the rewards bc just joined, they start earning next epoch
        recycler.next(_deadline(1));
        user2.mint(5e18);
        realloc_ttoke(address(recycler), 1e18);
        recycler.fill(2);

        // should be 7.333...e18
        // user2 gets (5 * 4 / 6) shares
        assertEq(recycler.totalShares(), 7333333333333333333);
        assertEq(recycler.epochAs(2).amount, 5e18);
        assertEq(recycler.epochAs(2).shares, 3333333333333333333);
        assertEq(recycler.balanceOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.balanceOf(address(user1)), 3e18 + 15e17);
        // loss of 1 decimal
        // this is expected - bc we avoid underflows when burning/exiting
        assertEq(recycler.balanceOf(address(user2)), 4999999999999999999);

        // check shares one last time
        recycler.poke(address(user0));
        recycler.poke(address(user1));
        recycler.poke(address(user2));
        assertEq(recycler.sharesOf(address(user0)), 1e18); // should be the same
        assertEq(recycler.sharesOf(address(user1)), 3e18); // should be the same
        assertEq(recycler.sharesOf(address(user2)), 3333333333333333333);
    }

    function testFillDiscontinousError() public {
        recycler.next(0);
        assertEq(recycler.cursor(), 1);

        recycler.next(0);
        assertEq(recycler.cursor(), 2);

        recycler.next(0);
        assertEq(recycler.cursor(), 3);

        expectRevert(abi.encodeWithSignature("Discontinuity()"));
        recycler.fill(2);
        expectRevert(abi.encodeWithSignature("Discontinuity()"));
        recycler.fill(3);

        recycler.fill(1);
        recycler.fill(2);
        recycler.fill(3);
        assertEq(recycler.epochAs(1).filled, true);
        assertEq(recycler.epochAs(2).filled, true);
        assertEq(recycler.epochAs(3).filled, true);
    }

    /**
     * `poke` (or `tick`, which is its internal name)
     */

    function testPoke() public {
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1e18);

        // fill and tick, and then check holdings
        recycler.fill(1);
        recycler.poke(address(user0));

        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
    }

    function testPokeOnEmptyBuffer() public {
        recycler.poke(address(this));
        assertEq(recycler.balanceOf(address(this)), 0);
        recycler.poke(address(user0));
        assertEq(recycler.balanceOf(address(user0)), 0);
        recycler.poke(address(user1));
        assertEq(recycler.balanceOf(address(user1)), 0);
    }

    function testPokeOnAlreadyTickedBuffer() public {
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1e18);

        // fill and tick, and then check holdings
        recycler.fill(1);
        recycler.poke(address(user0));
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);

        // nothing should change
        recycler.poke(address(user0));
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
    }

    /**
     * Integration
     */

    function testMultipleUsers() public {
        recycler.next(uint32(block.timestamp + 1));
        
        user0.mint(1e18);
        user1.mint(3e18);
        user2.mint(6e18);

        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);
        assertEq(recycler.bufferAs(address(user1)).amount, 3e18);
        assertEq(recycler.bufferAs(address(user2)).amount, 6e18);

        warp(block.timestamp + 2);
        // block should revert bc deadline passed
        realloc_ttoke(address(this), 1e18);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(this), 1e18);

        // no active coins, because not filled yet
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.balanceOf(address(user1)), 0);
        assertEq(recycler.balanceOf(address(user2)), 0);
        // fill
        recycler.fill(1);
        // simulate compounding by minting
        realloc_ttoke(address(recycler), 10e18);
        
        /// balance should double bc the epoch has been filled
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.balanceOf(address(user1)), 6e18);
        assertEq(recycler.balanceOf(address(user2)), 12e18);
        // shares should be zero bc accounts not ticked
        assertEq(recycler.sharesOf(address(user0)), 0);
        assertEq(recycler.sharesOf(address(user1)), 0);
        assertEq(recycler.sharesOf(address(user2)), 0);
        // buffer should be the same
        assertEq(recycler.bufferAs(address(user0)).epoch, 1);
        assertEq(recycler.bufferAs(address(user1)).epoch, 1);
        assertEq(recycler.bufferAs(address(user2)).epoch, 1);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);
        assertEq(recycler.bufferAs(address(user1)).amount, 3e18);
        assertEq(recycler.bufferAs(address(user2)).amount, 6e18);

        recycler.poke(address(user0));
        recycler.poke(address(user1));
        recycler.poke(address(user2));

        /// should be the same
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.balanceOf(address(user1)), 6e18);
        assertEq(recycler.balanceOf(address(user2)), 12e18);
        // should change bc we ticked
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.sharesOf(address(user1)), 3e18);
        assertEq(recycler.sharesOf(address(user2)), 6e18);
        // should be zero
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user1)).epoch, 0);
        assertEq(recycler.bufferAs(address(user2)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
        assertEq(recycler.bufferAs(address(user1)).amount, 0);
        assertEq(recycler.bufferAs(address(user2)).amount, 0);

        // go to next epoch: 2
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1e18);
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // fill epoch: 2 and now we should have shares for user0
        recycler.fill(2);

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // tick should reset buffer
        recycler.poke(address(user0));

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
    }
}
