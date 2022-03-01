// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.10;

import { DSTest } from "ds-test/test.sol";

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
        assertEq(requestOf(address(this)).cycle, 203);
        assertEq(requestOf(address(this)).assets, 1e18);
    }

    // should replace a previous request if it is withdrawable, and then create new one
    function testRequestReplace() public {
        realloc_toke(address(user0), 10e18);
        realloc_toke(address(user1), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        startPrank(address(user0));
        recycler.deposit(1e18, address(user0));
        stopPrank();
        startPrank(address(user1));
        recycler.deposit(1e18, address(user1));
        stopPrank();

        // check vault state
        assertEq(recycler.totalSupply(), 2e18);
        assertEq(recycler.totalAssets(), 2e18);

        startPrank(address(user0));
        recycler.request(5e17, address(user0));
        stopPrank();

        assertEq(recycler.totalSupply(), 2e18);
        assertEq(recycler.totalAssets(), 2e18);

        realloc_current_cycle_index(203);
        startPrank(address(user1));
        recycler.request(7e17, address(user1));
        stopPrank();

        assertEq(recycler.totalSupply(), 1e18 + 5e17);
        assertEq(recycler.totalAssets(), 1e18 + 5e17);

        // check vault state
        assertEq(toke.balanceOf(address(recycler)), 5e17);
        assertEq(recycler.cycleLock(), 205);

        // check user state
        // user0
        assertEq(recycler.balanceOf(address(user0)), 5e17);
        assertEq(requestOf(address(user0)).cycle, 203);
        assertEq(requestOf(address(user0)).assets, 5e17);
        assertEq(recycler.assetsOf(address(user0)), 5e17);
        // user1
        assertEq(recycler.balanceOf(address(user1)), 3e17);
        assertEq(requestOf(address(user1)).cycle, 205);
        assertEq(requestOf(address(user1)).assets, 7e17);
        assertEq(recycler.assetsOf(address(user1)), 3e17);
    }

    /**
     * withdraw
     */

    function testWithdraw() public {
        realloc_toke(address(this), 10e18);
        recycler.setDeadline(block.timestamp + 1);

        recycler.deposit(1e18, address(this));
        recycler.request(1e18, address(this));
        realloc_current_cycle_index(203); // current cycle is 201, change into 203
        recycler.withdraw(1e18, address(this), address(this));

        assertEq(toke.balanceOf(address(this)), 10e18);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(requestOf(address(this)).cycle, 0);
        assertEq(requestOf(address(this)).assets, 0);
        assertEq(recycler.assetsOf(address(this)), 0);
    }
}
