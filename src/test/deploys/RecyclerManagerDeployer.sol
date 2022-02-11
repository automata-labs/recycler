// SPDX-License-Identifier: GPL-3
pragma solidity ^0.8.0;

import "../../interfaces/IRecycler.sol";
import "../../RecyclerManager.sol";

contract RecyclerManagerDeployer is RecyclerManager {
    constructor(address token, IRecycler recycler) RecyclerManager(token, recycler) {}
}
