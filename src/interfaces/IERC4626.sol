// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";

interface IERC4626 is IERC20 {
    /// @notice Emitted on `deposit` and `mint`.
    event Deposit(address indexed sender, address indexed to, uint256 assets, uint256 shares);
    /// @notice Emitted on `withdraw` and `redeem`.
    event Withdraw(
        address indexed sender,
        address indexed to,
        address indexed from,
        uint256 assets,
        uint256 shares
    );

    /// @notice The address of the underlying token used by the vault.
    function asset() external view returns (address);

    /// @dev Returns the total amount of assets in `this` contract and in the `staking` contract.
    function totalAssets() external view returns (uint256 assets);
    /// @notice Returns the assets of an account.
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function assetsOf(address account) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function convertToShares(uint256 assets, uint256 epoch) external view returns (uint256 shares);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function maxDeposit(address account) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address to) external returns (uint256 shares);

    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function maxRequest(address account) external view returns (uint256 maxAssets);
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function previewRequest(uint256 assets) external view returns (uint256 shares);
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function request(uint256 assets, address from) external returns (uint256 shares);

    function maxWithdraw(address account) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function withdraw(uint256 assets, address to, address from) external returns (uint256 shares);
}
