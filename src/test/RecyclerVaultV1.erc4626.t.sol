// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.10;

import { DSTest } from "ds-test/test.sol";

import { RecyclerProxy } from "../RecyclerProxy.sol";
import { RecyclerVaultV1 } from "../RecyclerVaultV1.sol";
import { Utilities } from "./utils/Utilities.sol";

contract User {}

contract RecyclerVaultV1ERC4626Test is DSTest, Utilities {
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
     * totalAssets
     */

    function testTotalAssets() public {
        assertEq(recycler.totalAssets(), 0);
    }

    /**
     * balanceOf
     */

    function testBalanceOf() public {
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.balanceOf(address(user1)), 0);
        assertEq(recycler.balanceOf(address(user2)), 0);
    }
}
