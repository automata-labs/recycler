// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.10;

import { DSTest } from "ds-test/test.sol";

import { RecyclerProxy } from "../RecyclerProxy.sol";
import { RecyclerVaultV1 } from "../RecyclerVault.sol";
import { Utilities } from "./utils/Utilities.sol";

contract User {}

contract RecyclerVaultTest is DSTest, Utilities {
    RecyclerVaultV1 public implementationV1;
    RecyclerVaultV1 public recycler;

    User public user0;
    User public user1;
    User public user2;

    function _deadline(uint32 extra) internal view returns (uint32) {
        return uint32(block.timestamp) + extra;
    }

    function setUp() public {
        implementationV1 = new RecyclerVaultV1();
        recycler = RecyclerVaultV1(address(new RecyclerProxy(address(implementationV1), "")));
        user0 = new User();
        user1 = new User();
        user2 = new User();

        recycler.initialize(
            address(toke),
            address(staking),
            address(onchainvote),
            address(rewards),
            address(manager),
            0,
            type(uint256).max,
            type(uint256).max
        );

        // approves
        toke.approve(address(recycler), type(uint256).max);
        startPrank(address(user0));
        toke.approve(address(recycler), type(uint256).max);
        stopPrank();
        startPrank(address(user1));
        toke.approve(address(recycler), type(uint256).max);
        stopPrank();
        startPrank(address(user2));
        toke.approve(address(recycler), type(uint256).max);
        stopPrank();
    }

    /**
     * initialize
     */

    function testInitialize() public {
        assertEq(recycler.asset(), address(toke));
        assertEq(recycler.staking(), address(staking));
        assertEq(recycler.onchainvote(), address(onchainvote));
        assertEq(recycler.rewards(), address(rewards));
        assertEq(recycler.dust(), 0);
        assertEq(recycler.capacity(), type(uint256).max);
    }

    function testInitializeAuthError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.initialize(
            address(toke),
            address(staking),
            address(onchainvote),
            address(rewards),
            address(manager),
            1,
            1e18,
            type(uint256).max
        );
        stopPrank();
    }

    /**
     * deposit
     */

    function testDeposit() public {
        realloc_toke(address(this), 10e18);
        realloc_toke(address(user0), 10e18);
        recycler.next(uint32(block.timestamp) + 1);
        
        // deposit 1e18 from this
        recycler.deposit(1e18, address(this));

        // deposit 2e18 from user0
        startPrank(address(user0));
        recycler.deposit(2e18, address(user0));
        stopPrank();

        assertEq(toke.balanceOf(address(this)), 9e18);
        assertEq(toke.balanceOf(address(user0)), 8e18);

        assertEq(recycler.totalSupply(), 0);
        assertEq(recycler.totalAssets(), 3e18);
        assertEq(recycler.totalActive(), 0);
        assertEq(recycler.totalQueued(), 3e18);

        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.assetsOf(address(this)), 1e18);
        assertEq(recycler.assetsOf(address(user0)), 2e18);
        assertEq(recycler.activeOf(address(this)), 0);
        assertEq(recycler.activeOf(address(user0)), 0);
        assertEq(recycler.queuedOf(address(this)), 1e18);
        assertEq(recycler.queuedOf(address(user0)), 2e18);

        // fill
        warp(block.timestamp + 2);
        recycler.fill(1);
        // simulating claim
        realloc_toke(address(recycler), 1e18);
        // vault deposit
        recycler._deposit(1e18);

        assertEq(recycler.totalSupply(), 3e18);
        assertEq(recycler.totalAssets(), 4e18);
        assertEq(recycler.totalActive(), 4e18);
        assertEq(recycler.totalQueued(), 0);

        assertEq(recycler.balanceOf(address(this)), 1e18);
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.assetsOf(address(this)), 1e18 + 333333333333333333);
        assertEq(recycler.assetsOf(address(user0)), 2e18 + 666666666666666666);
        assertEq(recycler.activeOf(address(this)), 1e18 + 333333333333333333);
        assertEq(recycler.activeOf(address(user0)), 2e18 + 666666666666666666);
        assertEq(recycler.queuedOf(address(this)), 0);
        assertEq(recycler.queuedOf(address(user0)), 0);
    }

    // should mint multiple times on the same epoch
    // shouldn't make a difference if it's many small or one big tx
    function testDepositMultipleDepositsOnSameEpoch() public {
        realloc_toke(address(user0), 3e18);
        recycler.next(uint32(block.timestamp + 1));

        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        recycler.deposit(1e18, address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();
        assertEq(recycler.balanceOf(address(user0)), 0);

        recycler.fill(1);
        assertEq(recycler.balanceOf(address(user0)), 3e18);
    }

    // should tick the buffer and then mint afterwards
    function testDepositTickBufferIfFilled() public {
        realloc_toke(address(user0), 10e18);
        recycler.next(uint32(block.timestamp + 1));

        // deposit 1e18
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.assetsOf(address(user0)), 1e18);
        assertEq(recycler.activeOf(address(user0)), 0);
        assertEq(recycler.queuedOf(address(user0)), 1e18);
        assertEq(recycler.getState(address(user0)).epoch, 1);
        assertEq(recycler.getState(address(user0)).cycle, 0);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);
        assertEq(recycler.getState(address(user0)).shares, 0);

        warp(block.timestamp + 2);
        recycler.fill(1);

        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.assetsOf(address(user0)), 1e18);
        assertEq(recycler.activeOf(address(user0)), 1e18);
        assertEq(recycler.queuedOf(address(user0)), 0);
        assertEq(recycler.getState(address(user0)).epoch, 1);
        assertEq(recycler.getState(address(user0)).cycle, 0);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);
        assertEq(recycler.getState(address(user0)).shares, 0);

        // simulate compounding on the recycler...
        // claim 1e18
        realloc_toke(address(recycler), 1e18);
        recycler._deposit(1e18);

        // should revert if next epoch hasn't started
        startPrank(address(user0));
        expectRevert("Epoch expired");
        recycler.deposit(1e18, address(user0));
        stopPrank();

        // go next after compounding
        recycler.next(uint32(block.timestamp + 1));
        // deposit again with user to see that it ticks
        // deposit 1e18
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.assetsOf(address(user0)), 3e18);
        assertEq(recycler.activeOf(address(user0)), 2e18);
        assertEq(recycler.queuedOf(address(user0)), 1e18);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.getState(address(user0)).epoch, 2);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);

        recycler.fill(2);

        assertEq(recycler.balanceOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.assetsOf(address(user0)), 3e18);
        assertEq(recycler.activeOf(address(user0)), 3e18);
        assertEq(recycler.queuedOf(address(user0)), 0);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.getState(address(user0)).epoch, 2);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);
    }

    // throw if admin has paused mint
    function testDepositPausedError() public {
        realloc_toke(address(this), 1e18);

        recycler.pause(bytes4(keccak256(bytes("deposit(uint256,address)"))));
        expectRevert("Paused");
        recycler.deposit(1e18, address(this));
    }

    // throw when calling when only init:ed
    function testDepositOnInitializedContractError() public {
        realloc_toke(address(this), 1e18);
        expectRevert("Epoch expired");
        recycler.deposit(1e18, address(this));
    }

    // throw when not enough coins were transferred
    function testDepositInsufficientTransferError() public {
        recycler.next(_deadline(100));

        toke.approve(address(recycler), 0);
        expectRevert("SafeTransferFailed");
        recycler.deposit(1e18, address(this));
    }

    // throw when deadline is in the past, but we've deposited to it in the past
    function testDepositEpochExpiredWhenFilledError() public {
        recycler.next(_deadline(1));
        recycler.fill(1);

        realloc_toke(address(this), 1e18);
        expectRevert("Epoch expired");
        recycler.deposit(1e18, address(this));
    }

    // throw when deadline is in the past
    function testDepositEpochExpiredWhenDeadlinePassedError() public {
        recycler.next(_deadline(100));
        // timetravel to when deadline is hit
        warp(_deadline(101));

        realloc_toke(address(this), 1e18);
        expectRevert("Epoch expired");
        recycler.deposit(1e18, address(this));
    }

    // throw when a user has deposited into a past epoch, and that epoch has not been filled.
    // if the user's buffer was empty, then it wouldn't matter when they deposited - all that'd be
    // needed would be that the current epoch is available for deposits.
    //
    // to prevent the error, the admin needs to the fill the previous epochs.
    function testDepositIntoPastBufferButNotFilledYetError() public {
        recycler.next(_deadline(1));
        // deposit
        realloc_toke(address(this), 1e18);
        recycler.deposit(1e18, address(this));

        // go to next epochs and try deposit again, which should fail
        recycler.next(_deadline(2)); // time does not actually need to increase, but w/e
        recycler.next(_deadline(3));

        // throw error
        realloc_toke(address(this), 1e18);
        expectRevert("Buffer exists");
        recycler.deposit(1e18, address(this));
    }

    /**
     * withdraw
     */

    function testWithdraw() public {
        realloc_toke(address(this), 1e18);

        recycler.next(_deadline(1));
        recycler.deposit(1e18, address(this));
        recycler.fill(1);
        recycler.request(1e18);
        realloc_current_cycle_index(203);
        recycler.withdraw(1e18, address(this));

        assertEq(toke.balanceOf(address(recycler)), 0);
        assertEq(toke.balanceOf(address(this)), 1e18);
    }

    // when withdrawing when the min cycle index is not reached yet
    function testWithdrawTooEarly() public {
        realloc_toke(address(this), 1e18);

        recycler.next(_deadline(1));
        recycler.deposit(1e18, address(this));
        recycler.fill(1);
        recycler.request(1e18);
        expectRevert("Invalid cycle");
        recycler.withdraw(1e18, address(this));
    }

    function testWithdrawOverflow() public {
        realloc_toke(address(this), 1e18);

        recycler.next(_deadline(1));
        recycler.deposit(1e18, address(this));
        recycler.fill(1);
        recycler.request(1e18);
        realloc_current_cycle_index(203);
        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.withdraw(1e18 + 1, address(this));
    }

    function testWithdrawOnEmpty() public {
        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.withdraw(1, address(this));
    }

    function testWithdrawAmountZero() public {
        realloc_toke(address(this), 1e18);

        recycler.next(_deadline(1));
        recycler.deposit(1e18, address(this));
        recycler.fill(1);
        recycler.request(1e18);
        realloc_current_cycle_index(203);
        expectRevert("Insufficient withdrawal");
        recycler.withdraw(0, address(this));
    }

    /**
     * Integration
     */

    function testMultipleUsers() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        realloc_toke(address(user2), 10e18);
        recycler.next(uint32(block.timestamp + 1));
        
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();
        startPrank(address(user1));
        recycler.deposit(3e18, address(user1));
        stopPrank();
        startPrank(address(user2));
        recycler.deposit(6e18, address(user2));
        stopPrank();

        assertEq(recycler.getState(address(user0)).buffer, 1e18);
        assertEq(recycler.getState(address(user1)).buffer, 3e18);
        assertEq(recycler.getState(address(user2)).buffer, 6e18);

        warp(block.timestamp + 2);
        // block should revert bc deadline passed
        realloc_toke(address(this), 1e18);
        expectRevert("Epoch expired");
        recycler.deposit(1e18, address(this));

        // no shares yet, because not filled
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.balanceOf(address(user1)), 0);
        assertEq(recycler.balanceOf(address(user2)), 0);
        // fill
        recycler.fill(1);
        // simulate compounding by minting and depositing
        realloc_toke(address(recycler), 10e18);
        recycler._deposit(10e18);
        
        /// shares should automatically tick when viewing
        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.balanceOf(address(user1)), 3e18);
        assertEq(recycler.balanceOf(address(user2)), 6e18);
        // assets should show double
        assertEq(recycler.assetsOf(address(user0)), 2e18);
        assertEq(recycler.assetsOf(address(user1)), 6e18);
        assertEq(recycler.assetsOf(address(user2)), 12e18);
        // state should be the same because not ticked on-chain
        assertEq(recycler.getState(address(user0)).epoch, 1);
        assertEq(recycler.getState(address(user1)).epoch, 1);
        assertEq(recycler.getState(address(user2)).epoch, 1);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);
        assertEq(recycler.getState(address(user1)).buffer, 3e18);
        assertEq(recycler.getState(address(user2)).buffer, 6e18);

        recycler.poke(address(user0));
        recycler.poke(address(user1));
        recycler.poke(address(user2));

        /// should be the same
        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.balanceOf(address(user1)), 3e18);
        assertEq(recycler.balanceOf(address(user2)), 6e18);
        // should be the same
        assertEq(recycler.assetsOf(address(user0)), 2e18);
        assertEq(recycler.assetsOf(address(user1)), 6e18);
        assertEq(recycler.assetsOf(address(user2)), 12e18);
        // should be zero
        assertEq(recycler.getState(address(user0)).epoch, 0);
        assertEq(recycler.getState(address(user1)).epoch, 0);
        assertEq(recycler.getState(address(user2)).epoch, 0);
        assertEq(recycler.getState(address(user0)).buffer, 0);
        assertEq(recycler.getState(address(user1)).buffer, 0);
        assertEq(recycler.getState(address(user2)).buffer, 0);

        // go to next epoch: 2
        recycler.next(uint32(block.timestamp + 1));
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();
        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.assetsOf(address(user0)), 3e18);
        assertEq(recycler.activeOf(address(user0)), 2e18);
        assertEq(recycler.queuedOf(address(user0)), 1e18);
        assertEq(recycler.getState(address(user0)).epoch, 2);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);

        // fill epoch: 2 and now we should have shares for user0
        recycler.fill(2);

        assertEq(recycler.balanceOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.assetsOf(address(user0)), 3e18);
        assertEq(recycler.activeOf(address(user0)), 3e18);
        assertEq(recycler.queuedOf(address(user0)), 0);
        assertEq(recycler.getState(address(user0)).epoch, 2);
        assertEq(recycler.getState(address(user0)).buffer, 1e18);

        // tick should reset buffer
        recycler.poke(address(user0));

        assertEq(recycler.balanceOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.assetsOf(address(user0)), 3e18);
        assertEq(recycler.activeOf(address(user0)), 3e18);
        assertEq(recycler.queuedOf(address(user0)), 0);
        assertEq(recycler.getState(address(user0)).epoch, 0);
        assertEq(recycler.getState(address(user0)).buffer, 0);
    }
}
