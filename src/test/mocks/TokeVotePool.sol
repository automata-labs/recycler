// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "yield-utils-v2/token/ERC20.sol";

import "../../libraries/SafeTransfer.sol";

contract TokeVotePool is ERC20 {
    using SafeTransfer for address;

    ERC20 public underlyer; // Underlying ERC20 token

    constructor(
        ERC20 underlyer_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(
        name_,
        symbol_,
        decimals_
    ) {
        underlyer = underlyer_;
    }

    function deposit(uint256 amount) external {
        _deposit(msg.sender, msg.sender, amount);
    }

    function _deposit(
        address fromAccount,
        address toAccount,
        uint256 amount
    ) internal {
        require(amount > 0, "INVALID_AMOUNT");
        require(toAccount != address(0), "INVALID_ADDRESS");

        _mint(toAccount, amount);
        address(underlyer).safeTransferFrom(fromAccount, address(this), amount);
    }
}
