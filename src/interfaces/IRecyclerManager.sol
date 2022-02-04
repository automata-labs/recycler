// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IRecycler.sol";

interface IRecyclerManager {
    /// @notice The same token as `coin` in the recycler contract.
    function token() external view returns (address);
    /// @notice The core vault contract.
    function recycler() external view returns (IRecycler);

    /// @notice Calls the `mint` function on the vault.
    function mint(address to, uint256 amount) external;
    /// @notice Callback from the vault to pull funds.
    /// @dev Should only be callable by the vault.
    function mintCallback(bytes memory data) external;
}
