// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IReactor {
    function load(uint256 amount, bytes memory data) external;

    function unload(address to, uint256 amount) external;

    function mint(address to, uint256 amount) external returns (uint256 shares);

    function burn(address from, address to, uint256 shares) external returns (uint256 amount);

    function execute(
        address[] calldata targets,
        bytes[] calldata datas
    ) external returns (bytes[] memory results);
}
