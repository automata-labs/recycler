// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../libraries/data/Buffer.sol";
import "../libraries/data/Coin.sol";
import "../libraries/data/Epoch.sol";
import "../libraries/data/Share.sol";

contract MathTest is DSTest {
    using Buffer for Buffer.Data;

    mapping(uint256 => Epoch.Data) public epochOf;

    function testBufferToQueued(uint32 epoch, uint224 amount, bool filled) public {
        epochOf[epoch].filled = filled;

        Buffer.Data memory buffer = Buffer.Data({ epoch: epoch, amount: amount });

        if (filled) {
            assertEq(buffer.toQueued(epochOf), 0);
        } else {
            assertEq(buffer.toQueued(epochOf), amount);
        }
    }

    function testBufferToShares(
        uint32 epoch,
        uint224 amount,
        uint104 epochAmount,
        uint104 epochShares,
        bool filled
    ) public {
        epochOf[epoch].amount = epochAmount;
        epochOf[epoch].shares = epochShares;
        epochOf[epoch].filled = filled;

        Buffer.Data memory buffer = Buffer.Data({ epoch: epoch, amount: amount });

        if (amount <= epochAmount) {
            if (filled) {
                assertEq(buffer.toShares(epochOf), (amount * epochShares) / epochAmount);
            } else {
                assertEq(buffer.toShares(epochOf), 0);
            }
        }
    }
}
