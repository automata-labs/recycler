// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerVaultV0 {
    function allow(address addr) external;

    /// @notice Execute arbitrary calls.
    /// @dev Used for e.g. claiming and voting.
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external returns (bytes[] memory results);
}
