// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.0;

import "../../Recycler.sol";

contract RecyclerDeployer is Recycler {
    constructor() Recycler(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930, 0) {}
}
