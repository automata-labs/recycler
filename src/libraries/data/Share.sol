// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Epoch.sol";

library Share {
    function toCoins(
        uint256 shares,
        uint256 totalCoins,
        uint256 totalShares
    ) internal pure returns (uint256) {
        if (totalShares > 0) {
            return shares * totalCoins / totalShares;
        } else {
            return 0;
        }
    }
}
