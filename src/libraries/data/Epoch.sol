// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library Epoch {
    struct Data {
        /// @dev The timestamp in which this epoch becomes outdated.
        uint32 deadline;
        /// @dev The total amount of tokens deposited during this epoch (batch of cycles).
        uint104 buffer;
        /// @dev The total shares redeemable by the depositors during this cycle.
        uint104 shares;
        /// @dev Whether the epoch has been filled with shares or not.
        bool filled;
    }

    function toShares(
        Epoch.Data memory self,
        uint256 totalSupply,
        uint256 totalActive
    ) internal pure returns (uint256) {
        if (totalSupply > 0 && totalActive > 0) {
            return (self.buffer * totalSupply) / totalActive;
        } else {
            return self.buffer;
        }
    }
}
