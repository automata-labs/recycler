// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../Cast.sol";
import "./Epoch.sol";

library State {
    using Cast for uint256;

    struct Data {
        uint16 epoch; // epoch that was deposited into
        uint32 cycle; // cycle which withdraw can be called
        // if epoch > 0, then deposit buffer
        // if cycle > 0, then withdrawal buffer
        // both epoch and cycle cannot be greater than zero at the same time
        uint96 buffer;
        uint96 shares;
    }
}
