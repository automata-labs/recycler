// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.0;

import "../../Recycler.sol";

contract RecyclerDeployer is Recycler {
    constructor(address token, uint256 dust) Recycler(token, dust) {}
}
