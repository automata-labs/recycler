// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Epoch {
    struct Data {
        /// @dev The timestamp in which this epoch becomes outdated.
        uint32 deadline;
        /// @dev The total amount of tokens deposited during this epoch (batch of cycles).
        uint104 amount;
        /// @dev The total shares redeemable by the depositors during this cycle.
        uint104 shares;
        /// @dev Whether the epoch has been filled with shares or not.
        bool filled;
    }

    function toShares(
        Epoch.Data memory self,
        uint256 totalShares,
        uint256 totalCoins
    ) internal pure returns (uint256) {
        if (totalShares > 0 && totalCoins > 0) {
            return self.amount * totalShares / totalCoins;
        } else {
            return self.amount;
        }
    }
}
