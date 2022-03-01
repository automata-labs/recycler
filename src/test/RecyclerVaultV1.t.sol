// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.10;

import { DSTest } from "ds-test/test.sol";

import { IOnChainVoteL1 } from "../interfaces/external/IOnChainVoteL1.sol";
import { Request } from "../libraries/data/Request.sol";
import { RecyclerProxy } from "../RecyclerProxy.sol";
import { RecyclerVaultV1 } from "../RecyclerVaultV1.sol";
import { Utilities } from "./utils/Utilities.sol";

contract User {}

contract RecyclerVaultV2Test is DSTest, Utilities {
    RecyclerVaultV1 public implementationV1;
    RecyclerVaultV1 public recycler;

    User public user0;
    User public user1;
    User public user2;

    function _deadline(uint32 extra) internal view returns (uint32) {
        return uint32(block.timestamp) + extra;
    }

    function requestOf(address account) internal view returns (Request.Data memory) {
        (uint32 cycle, uint224 assets) = recycler.requestOf(account);
        return Request.Data({ cycle: cycle, assets: assets });
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
            type(uint256).max
        );
        recycler.give(type(uint256).max);

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

    function testDeposit() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        recycler.deposit(1e18, address(this));
        assertEq(recycler.balanceOf(address(this)), 1e18);
        assertEq(recycler.assetsOf(address(this)), 1e18);

        assertEq(recycler.totalSupply(), 1e18);
    }

    function testDepositMultipleUsers() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        assertEq(recycler.totalSupply(), 1e18);

        startPrank(address(user1));
        recycler.deposit(1e18, address(user1));
        stopPrank();

        assertEq(recycler.totalSupply(), 2e18);
    }

    function testDepositWithRate() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        realloc_toke(address(user2), 10e18);
        recycler.setRate(6491599622312253);
        recycler.setDeadline(block.timestamp + 1);

        startPrank(address(user0));
        recycler.deposit(8e18, address(user0));
        stopPrank();
        assertEq(recycler.balanceOf(address(user0)), 8e18);
        assertEq(recycler.assetsOf(address(user0)), 8e18);

        // deposit w/ rate for user1
        recycler.cache();
        startPrank(address(user1));
        recycler.deposit(2e18, address(user1));
        stopPrank();
        assertEq(recycler.balanceOf(address(user1)), 1987100538892230720);
        assertEq(recycler.assetsOf(address(user1)), 1989667102232496329);

        // deposit w/ rate for user2
        startPrank(address(user2));
        recycler.deposit(2e18, address(user2));
        stopPrank();
        assertEq(recycler.balanceOf(address(user2)), 1987100538892230720);
        assertEq(recycler.assetsOf(address(user2)), 1991381830972121262);
        // user1's should eq. user2's
        assertEq(recycler.assetsOf(address(user1)), 1991381830972121262);

        // claim rewards and see that the balance goes back to normal
        uint256 rewards = 8e18 * recycler.rate() / recycler.UNIT_RATE();
        realloc_toke(address(recycler), rewards);
        recycler.stake(rewards);
        assertEq(recycler.balanceOf(address(user1)), 1987100538892230720);
        assertEq(recycler.assetsOf(address(user1)), 1999999999999999999);
        assertEq(recycler.balanceOf(address(user2)), 1987100538892230720);
        assertEq(recycler.assetsOf(address(user2)), 1999999999999999999);
    }

    function testDepositZeroRevert() public {
        expectRevert("Insufficient deposit");
        recycler.deposit(0, address(this));
    }

    function testDepositCapacityRevert() public {
        realloc_toke(address(this), 10e18);

        recycler.setCapacity(0);
        expectRevert("Capacity overflow");
        recycler.deposit(1, address(this));
    }

    function testDepositDeadlineRevert() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(0);
        recycler.setCapacity(1e18);

        expectRevert("Deadline");
        recycler.deposit(1, address(this));
    }

    function testDepositFailedTransferRevert() public {
        recycler.setDeadline(block.timestamp + 100);
        recycler.setCapacity(1e18);

        expectRevert("SafeTransferFailed");
        recycler.deposit(1, address(this));
    }

    function testDepositFailedTransferApproveRevert() public {
        realloc_toke(address(this), 10e18);
        toke.approve(address(recycler), 0);
        recycler.setDeadline(block.timestamp + 100);
        recycler.setCapacity(1e18);

        expectRevert("SafeTransferFailed");
        recycler.deposit(1, address(this));
    }

    function testDepositVaultNotApprovedForStakingRevert() public {
        realloc_toke(address(this), 10e18);
        recycler.give(0);
        recycler.setDeadline(block.timestamp + 100);
        recycler.setCapacity(1e18);

        expectRevert("ERC20: transfer amount exceeds allowance");
        recycler.deposit(1e18, address(this));
    }

    function testDepositWeirdConversionRevert() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        recycler.deposit(1e18, address(this));
        realloc_toke(address(recycler), 100e18);
        recycler.stake(100e18);
        recycler.cache();

        expectRevert("Insufficient conversion");
        recycler.deposit(1, address(this));
    }

    /**
     * request
     */

    function testRequest() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        recycler.deposit(1e18, address(this));
        recycler.request(1e18, address(this));

        mine(1);
        warp(block.timestamp + 10000);

        assertEq(recycler.totalSupply(), 1e18);
        assertEq(recycler.totalAssets(), 1e18);
        assertEq(requestOf(address(this)).cycle, 202);
        assertEq(requestOf(address(this)).assets, 1e18);
    }

    // should replace a previous request if it is withdrawable, and then create new one
    function testRequestReplace() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        // deposit with user0 and user1
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();
        startPrank(address(user1));
        recycler.deposit(1e18, address(user1));
        stopPrank();

        // check vault state
        assertEq(recycler.totalSupply(), 2e18);
        assertEq(recycler.totalAssets(), 2e18);

        // user0 request withdrawal
        startPrank(address(user0));
        recycler.request(5e17, address(user0));
        stopPrank();

        // vault state should not be affected
        // this is because vault state changes on `withdraw/withdrawAll`, not on `request`
        assertEq(recycler.totalSupply(), 2e18);
        assertEq(recycler.totalAssets(), 2e18);

        // user1 request withdraw after cycle lock
        // this should also trigger a withdrawAll, and change the vault state
        realloc_current_cycle_index(202);
        startPrank(address(user1));
        recycler.request(7e17, address(user1));
        stopPrank();

        // check vault state
        assertEq(recycler.totalSupply(), 1e18 + 5e17);
        assertEq(recycler.totalAssets(), 1e18 + 5e17);
        assertEq(toke.balanceOf(address(recycler)), 5e17);

        // check user state
        // user0
        assertEq(recycler.balanceOf(address(user0)), 5e17);
        assertEq(requestOf(address(user0)).cycle, 202);
        assertEq(requestOf(address(user0)).assets, 5e17);
        assertEq(recycler.assetsOf(address(user0)), 5e17);
        assertEq(recycler.maxWithdraw(address(user0)), 5e17);
        // user1
        assertEq(recycler.balanceOf(address(user1)), 3e17);
        assertEq(requestOf(address(user1)).cycle, 203);
        assertEq(requestOf(address(user1)).assets, 7e17);
        assertEq(recycler.assetsOf(address(user1)), 3e17);
        assertEq(recycler.maxWithdraw(address(user1)), 0);

        // fast-forward and now user1's withdrawal should also show up
        realloc_current_cycle_index(203);
        assertEq(recycler.maxWithdraw(address(user1)), 7e17);

        // try withdrawing
        startPrank(address(user0));
        recycler.withdraw(recycler.maxWithdraw(address(user0)), address(user0), address(user0));
        stopPrank();
        startPrank(address(user1));
        recycler.withdraw(recycler.maxWithdraw(address(user1)), address(user1), address(user1));
        stopPrank();

        assertEq(toke.balanceOf(address(user0)), 9e18 + 5e17);
        assertEq(toke.balanceOf(address(user1)), 9e18 + 7e17);
        assertEq(requestOf(address(user0)).cycle, 0);
        assertEq(requestOf(address(user0)).assets, 0);
        assertEq(requestOf(address(user1)).cycle, 0);
        assertEq(requestOf(address(user1)).assets, 0);
    }
    
    function testRequestEmptyVaultWeirdConversionRevert() public {
        expectRevert("Insufficient conversion");
        recycler.request(1e18, address(this));
    }

    function testRequestNotEnoughApprovedRevert() public {
        realloc_toke(address(user0), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.request(1e18, address(user0));
    }

    /**
     * withdraw
     */

    function testWithdraw() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        recycler.deposit(1e18, address(this));
        recycler.request(1e18, address(this));
        realloc_current_cycle_index(202); // current cycle is 201, change into 202
        recycler.withdraw(1e18, address(this), address(this));

        assertEq(toke.balanceOf(address(this)), 10e18);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(requestOf(address(this)).cycle, 0);
        assertEq(requestOf(address(this)).assets, 0);
        assertEq(recycler.assetsOf(address(this)), 0);
    }

    function testWithdrawMultipleUsers() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        realloc_toke(address(user2), 10e18);
        recycler.setDeadline(block.timestamp + 10);

        // deposit user0
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        // deposit user1
        startPrank(address(user1));
        recycler.deposit(3e18, address(user1));
        stopPrank();

        // deposit user2
        startPrank(address(user2));
        recycler.deposit(6e18, address(user2));
        stopPrank();

        realloc_toke(address(recycler), 10e18);
        recycler.stake(10e18);

        // request user0
        assertEq(recycler.maxRequest(address(user0)), 2e18);
        startPrank(address(user0));
        recycler.request(2e18, address(user0));
        stopPrank();

        // request user1
        assertEq(recycler.maxRequest(address(user1)), 6e18);
        startPrank(address(user1));
        recycler.request(6e18, address(user1));
        stopPrank();

        // check user0
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.assetsOf(address(user0)), 0);
        assertEq(recycler.maxWithdraw(address(user0)), 0);
        assertEq(requestOf(address(user0)).cycle, 202);
        assertEq(requestOf(address(user0)).assets, 2e18);

        // check user1
        assertEq(recycler.balanceOf(address(user1)), 0);
        assertEq(recycler.assetsOf(address(user1)), 0);
        assertEq(recycler.maxWithdraw(address(user1)), 0);
        assertEq(requestOf(address(user1)).cycle, 202);
        assertEq(requestOf(address(user1)).assets, 6e18);

        realloc_current_cycle_index(202);

        // check vault
        assertEq(recycler.buffer(), 4e18); // this is shares

        assertEq(recycler.maxWithdraw(address(user0)), 2e18);
        startPrank(address(user0));
        recycler.withdraw(2e18, address(user0), address(user0));
        stopPrank();
        assertEq(toke.balanceOf(address(user0)), 11e18);

        assertEq(recycler.maxWithdraw(address(user1)), 6e18);
        startPrank(address(user1));
        recycler.withdraw(6e18, address(user1), address(user1));
        stopPrank();
        assertEq(toke.balanceOf(address(user1)), 13e18);

        // check vault after
        assertEq(recycler.buffer(), 0);
    }

    function testWithdrawInFutureCycle() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        realloc_toke(address(user2), 10e18);
        recycler.setDeadline(block.timestamp + 10);

        // deposit user0
        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();

        // deposit user1
        startPrank(address(user1));
        recycler.deposit(3e18, address(user1));
        stopPrank();

        // deposit user2
        startPrank(address(user2));
        recycler.deposit(6e18, address(user2));
        stopPrank();

        // simulated claim
        realloc_toke(address(recycler), 10e18);
        recycler.stake(10e18);

        // request user0
        startPrank(address(user0));
        recycler.request(recycler.maxRequest(address(user0)), address(user0));
        stopPrank();

        // fast-forward cycle
        realloc_current_cycle_index(202);

        // request user1
        startPrank(address(user1));
        recycler.request(recycler.maxRequest(address(user1)), address(user1));
        stopPrank();

        // fast-forward cycle
        realloc_current_cycle_index(203);

        startPrank(address(user0));
        recycler.withdraw(recycler.maxWithdraw(address(user0)), address(user0), address(user0));
        stopPrank();

        assertEq(toke.balanceOf(address(user0)), 11e18);
    }

    /**
     * give
     */

     function testGive() public {
        recycler.give(type(uint256).max - 1);
        assertEq(toke.allowance(address(recycler), address(staking)), type(uint256).max - 1);
    }

    // should revert because msg.sender is not auth:ed for recycler
    function testGiveUnauthorizedError() public {
        startPrank(address(user0));
        expectRevert("Denied");
        recycler.give(0);
    }

    /**
     * vote
     */

    function testVote() public {
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
}
