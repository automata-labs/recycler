// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../libraries/Auth.sol";
import "../libraries/Pause.sol";
import "./utils/Vm.sol";

contract C is Auth, Pause {
    uint256 public value;

    function set(uint256 value_) public playback {
        value = value_;
    }
}

contract PauseTest is DSTest, Vm {
    C public c = new C();

    function setUp() public {
        c = new C();
    }

    function testPause() public {
        c.set(1);
        c.pause(C.set.selector);
        expectRevert("Paused");
        c.set(2);
    }

    function testUnpause() public {
        c.pause(C.set.selector);
        c.unpause(C.set.selector);
        c.set(1);
        assertEq(c.value(), 1);
    }

    function testDestroy() public {
        c.destroy(C.set.selector);
        expectRevert("Paused");
        c.set(1);
        expectRevert("Destroyed");
        c.unpause(C.set.selector);
    }
}
