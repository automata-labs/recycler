// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokeVotePool {
    function balanceOf(address account) external view returns (uint256);

    /// @dev Used for claiming and staking for compounding.
    function deposit(uint256 amount) external;

    /// @dev Can be used to instantly stake and deposit into catalyst for pure TOKE.
    function depositFor(address account, uint256 amount) external;
}
