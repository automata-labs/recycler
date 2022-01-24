// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Epoch {
    struct Data {
        /// @dev The timestamp in which this epoch becomes outdated.
        uint32 deadline;
        /// @dev The total amount of tokens deposited during this epoch (batch of cycles).
        uint104 tokens;
        /// @dev The total shares redeemable by the depositors during this cycle.
        uint104 shares;
        /// @dev If the epoch has been filled with shares.
        bool filled;
    }
}
