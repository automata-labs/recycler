// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Lock {
    error Locked();

    bool public __locked = false;

    modifier lock() {
        if (__locked)
            revert Locked();

        __locked = true;
        _;
        __locked = false;
    }
}
