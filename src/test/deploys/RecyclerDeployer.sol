// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.0;

import "../../Recycler.sol";

contract RecyclerDeployer is Recycler {
    constructor(
        address underlying,
        address derivative,
        address onchainvote,
        address rewards,
        uint256 dust
    ) Recycler(
        underlying,
        derivative,
        onchainvote,
        rewards,
        dust
    ) {}
}
