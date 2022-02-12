// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.0;

import "../../Operator.sol";

contract OperatorDeployer is Operator {
    constructor(
        address recycler_,
        address underlying_,
        address derivative_,
        address onchainvote_,
        address rewards_
    ) Operator(
        recycler_,
        underlying_,
        derivative_,
        onchainvote_,
        rewards_
    ) {}
}
