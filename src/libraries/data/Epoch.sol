// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library Epoch {
    struct Data {
        /// @dev The timestamp in which this epoch becomes outdated.
        uint32 deadline;
        /// @dev The total amount of assets deposited during this epoch.
        uint104 assets;
        /// @dev The total shares minted by the depositors during this cycle.
        uint104 shares;
        /// @dev Whether the epoch has been filled with shares or not.
        bool filled;
    }
}
