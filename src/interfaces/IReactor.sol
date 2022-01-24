// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReactor {
    /// @notice Returns the underlying token address.
    /// @dev Expected to be the `tTOKE` token address.
    function token() external view returns (address);

    /// @notice The amount of shares that are locked on a fresh `mint`.
    function dust() external view returns (uint96);

    /// @notice The amount of tokens that are being queued for the next cycle(s).
    /// @dev This differentiates the queued- and joined token amounts from each other. Because
    ///     rewards are distrbuted every week by the Tokemak Labs team, tokens needs to queued first.
    function buffer() external view returns (uint256);

    /// @notice Loads tokens into the reactor buffer.
    function load(uint256 amount, bytes memory data) external;

    /// @notice Unloads tokens from the reactor buffer.
    function unload(address to, uint256 amount) external;

    /// @notice Mints shares from buffered tokens.
    /// @dev Shares cannot be minted from another other way. If the buffer is to be bypassed, a new
    ///     contract on top will have to be written.
    function mint(address to, uint256 amount) external returns (uint256 shares);

    /// @notice Burn shares to redeem its shares of tokens from the pool.
    function burn(address from, address to, uint256 shares) external returns (uint256 amount);

    /// @notice Execute arbitrary calls.
    /// @dev Used mainly for voting, approving, claiming and staking rewards.
    function execute(
        address[] calldata targets,
        bytes[] calldata datas
    ) external returns (bytes[] memory results);
}
