// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Epoch.sol";

library Buffer {
    struct Data {
        uint32 epoch;
        uint224 amount;
    }

    function toQueued(
        Buffer.Data memory self,
        mapping(uint256 => Epoch.Data) storage epochs
    ) internal view returns (uint256) {
        if (epochs[self.epoch].filled) {
            return 0;
        } else {
            return self.amount;
        }
    }

    function toShares(
        Buffer.Data memory self,
        mapping(uint256 => Epoch.Data) storage epochs
    ) internal view returns (uint256) {
        if (epochs[self.epoch].amount > 0 && epochs[self.epoch].filled) {
            return (self.amount * epochs[self.epoch].shares) / epochs[self.epoch].amount;
        } else {
            return 0;
        }
    }
}
