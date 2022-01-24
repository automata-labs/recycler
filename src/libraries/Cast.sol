// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Cast {
    function u224(uint256 x) internal pure returns (uint224 y) {
        require (x <= type(uint224).max, "Cast");
        y = uint224(x);
    }

    function u128(uint256 x) internal pure returns (uint128 y) {
        require (x <= type(uint128).max, "Cast");
        y = uint128(x);
    }

    function u112(uint256 x) internal pure returns (uint112 y) {
        require (x <= type(uint112).max, "Cast");
        y = uint112(x);
    }

    function u32(uint256 x) internal pure returns (uint32 y) {
        require (x <= type(uint32).max, "Cast");
        y = uint32(x);
    }

    function u24(uint256 x) internal pure returns (uint24 y) {
        require (x <= type(uint24).max, "Cast");
        y = uint24(x);
    }
}
