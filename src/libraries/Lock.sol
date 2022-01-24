// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Lock {
    error Locked();

    bool public locked = false;

    modifier lock() {
        if (locked)
            revert Locked();

        locked = true;
        _;
        locked = false;
    }
}
