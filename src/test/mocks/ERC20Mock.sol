// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "yield-utils-v2/token/ERC20Permit.sol";

contract ERC20Mock is ERC20Permit {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20Permit(
        name_,
        symbol_,
        decimals_
    ) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
