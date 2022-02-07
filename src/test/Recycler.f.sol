// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Recycler.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract RecyclerFuzz is DSTest, Vm, Utilities {
    Recycler public recycler;

    function assertEq(bool x, bool y) internal {
        if (x != y) {
            emit log("Error: Assertion Failed");
            fail();
        }
    }

    function write_buffer(uint256 amount) public {
        store(address(recycler), bytes32(uint256(6)), bytes32(uint256(amount)));
    }

    function write_epoch(
        uint256 epoch,
        uint32 deadline,
        uint104 amount,
        uint104 shares,
        bool filled
    ) public {
        uint256 word;

        word = (filled) ? (1 << 240) : 0;
        word += shares << 136;
        word += amount << 32;
        word += deadline << 0;

        store(address(recycler), keccak256(abi.encode(epoch, 9)), bytes32(uint256(word)));
    }

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

        mint(address(recycler), amount);
        write_buffer(amount);
        assertEq(recycler.totalBuffer(), amount);

        write_epoch(epoch, deadline, amount, 0, false);
        recycler.fill(epoch);
        assertEq(recycler.epochAs(epoch).filled, true);
    }
}
