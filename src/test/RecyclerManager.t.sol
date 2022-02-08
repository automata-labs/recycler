// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/IRecycler.sol";
import "../Recycler.sol";
import "../RecyclerManager.sol";
import "./utils/Utilities.sol";

contract User {}

contract RecyclerManagerTest is DSTest, Utilities {
    Recycler public recycler;
    RecyclerManager public recyclerManager;

    User public user0;
    User public user1;

    function setUp() public {
        recycler = new Recycler(address(tokeVotePool), 0);
        recyclerManager = new RecyclerManager(address(tokeVotePool), IRecycler(recycler));

        user0 = new User();
        user1 = new User();

        recycler.next(uint32(block.timestamp + 1));
        tokeVotePool.approve(address(recyclerManager), type(uint256).max);
    }

    /**
     * `mint`
     */

    function testMint() public {
        mint(address(this), 1e18);
        recyclerManager.mint(address(this), 1e18);
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
    }

    function testMintZeroError() public {
        mint(address(this), 1e18);
        expectRevert(abi.encodeWithSignature("ParameterDust()"));
        recyclerManager.mint(address(this), 0);
    }

    /**
     * `mintCallback`
     */

    struct CallbackData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    function testMintCallback() public {
        mint(address(user0), 1e18);
        startPrank(address(user0));
        tokeVotePool.approve(address(recyclerManager), type(uint256).max);
        stopPrank();

        startPrank(address(recycler));
        recyclerManager.mintCallback(abi.encode(CallbackData({
            token: address(tokeVotePool),
            payer: address(user0),
            payee: address(user1),
            amount: 1e18
        })));

        assertEq(tokeVotePool.balanceOf(address(user0)), 0);
        assertEq(tokeVotePool.balanceOf(address(user1)), 1e18);
    }

    // should not allow anyone expect for recycler to call the `mintCallback` function
    function testMintCallbackNotRecyclerError() public {
        mint(address(user0), 1e18);
        startPrank(address(user0));
        tokeVotePool.approve(address(recyclerManager), type(uint256).max);
        stopPrank();

        // try as address(this), should still fail
        expectRevert("Unauthorized");
        recyclerManager.mintCallback(abi.encode(CallbackData({
            token: address(tokeVotePool),
            payer: address(user0),
            payee: address(user1),
            amount: 1e18
        })));

        // try as user0, should fail
        startPrank(address(user0));
        expectRevert("Unauthorized");
        recyclerManager.mintCallback(abi.encode(CallbackData({
            token: address(tokeVotePool),
            payer: address(user0),
            payee: address(user1),
            amount: 1e18
        })));
        stopPrank();

        // try as user1, should still fail
        startPrank(address(user1));
        expectRevert("Unauthorized");
        recyclerManager.mintCallback(abi.encode(CallbackData({
            token: address(tokeVotePool),
            payer: address(user0),
            payee: address(user1),
            amount: 1e18
        })));
        stopPrank();
    }
}
