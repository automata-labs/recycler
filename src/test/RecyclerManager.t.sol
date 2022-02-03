// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/IRecycler.sol";
import "../Recycler.sol";
import "../RecyclerManager.sol";
import "./utils/Utilities.sol";

contract RecyclerManagerTest is DSTest, Utilities {
    Recycler public recycler;
    RecyclerManager public recyclerManager;

    function setUp() public {
        recycler = new Recycler(address(tokeVotePool), 0);
        recyclerManager = new RecyclerManager(address(tokeVotePool), IRecycler(recycler));

        recycler.next(uint32(block.timestamp + 1));
        tokeVotePool.approve(address(recyclerManager), type(uint256).max);
    }

    function testMint() public {
        mint(address(this), 1e18);
        recyclerManager.mint(address(this), 1e18);
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
    }
}
