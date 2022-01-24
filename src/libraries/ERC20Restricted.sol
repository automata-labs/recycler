// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";

abstract contract ERC20Restricted is IERC20, IERC20Metadata {
    error ApproveError();
    error TransferError();

    string internal _name;
    string internal _symbol;
    uint8 internal immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /// @inheritdoc IERC20Metadata
    function name() external view virtual returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external view virtual returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IERC20
    function totalSupply() external view virtual returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC20
    function balanceOf(address) external view virtual returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC20
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) external pure returns (bool) {
        revert TransferError();
    }

    /// @inheritdoc IERC20
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert TransferError();
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) external pure returns (bool) {
        revert ApproveError();
    }
}
