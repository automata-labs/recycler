// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;

import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Auth } from "./libraries/Auth.sol";
import { Lock } from "./libraries/Lock.sol";
import { Pause } from "./libraries/Pause.sol";

contract RecyclerProxy is ERC1967Proxy, Auth, Pause, Lock {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}
}
