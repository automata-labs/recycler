// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRecyclerState {
    /// @notice The Tokemak token.
    function underlying() external view returns (address);
    /// @notice The staked Tokemak token.
    function derivative() external view returns (address);
    /// @notice The Tokemak voting contract.
    function onchainvote() external view returns (address);
    /// @notice The Tokemak rewards contract.
    function rewards() external view returns (address);

    /// @notice The minimum amount of tokens that needs to be deposited.
    function dust() external view returns (uint256);
    /// @notice The max capacity of the vault (in `coin`).
    function capacity() external view returns (uint256);
    /// @notice The current epoch id.
    function cursor() external view returns (uint256);

    /// @notice The total amount of shares issued.
    function totalShares() external view returns (uint256);
    /// @notice The total amount of tokens being buffered into shares.
    function totalBuffer() external view returns (uint256);
    /// @notice The mapping for keeping track of shares that each account has.
    /// @param account The address of an account.
    function sharesOf(address account) external view returns (uint256);
    /// @notice The mapping for keeping track of buffered tokens.
    /// @param account The address of an account.
    /// @return epoch The epoch of an account's buffer.
    /// @return amount The amount of tokens being buffered/queued into `epoch`.
    function bufferOf(address account) external view returns (uint32 epoch, uint224 amount);
    /// @notice The epoch mapping to batch deposits and -share issuances.
    /// @param epoch The epoch id.
    /// @return deadline The unix timestamp of the deadline. When passed, the epoch becomes inactive.
    /// @return amount The amount of tokens being buffered/queued for the `epoch` epoch.
    /// @return shares The amount of shares minted for the `amount` of this epoch. If `filled` is
    /// `false`, then shares will always be zero. When `filled` is `true`, then it can be non-zero.
    /// @return filled Whether the epoch has been filled with shares or not.
    function epochOf(uint256 epoch) external view returns (
        uint32 deadline,
        uint104 amount,
        uint104 shares,
        bool filled
    );
    /// @notice The mapping of valid reactor keys that the vault can vote with.
    function keys(bytes32 key) external view returns (bool);
}
