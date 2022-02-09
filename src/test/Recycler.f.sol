// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Recycler.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract RecyclerFuzz is DSTest, Vm, Utilities {
    Recycler public recycler;

    function setUp() public {
        recycler = new Recycler(address(tokeVotePool), 0);
    }

    function testNextFuzz(uint32 deadline) public {
        uint256 cursor = recycler.cursor();
        recycler.next(deadline);
        assertEq(recycler.cursor(), cursor + 1);
        assertEq(recycler.epochAs(cursor + 1).deadline, deadline);
    }

    function testFillFuzz(uint32 deadline, uint104 amount) public {
        uint256 epoch = recycler.next(1);

        realloc_ttoke(address(recycler), amount);
        realloc_buffer(address(recycler), amount);
        assertEq(recycler.totalBuffer(), amount);

        realloc_epoch(address(recycler), epoch, deadline, amount, 0, false);
        recycler.fill(epoch);
        assertEq(recycler.epochAs(epoch).filled, true);
    }
}
