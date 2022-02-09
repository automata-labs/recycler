// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../libraries/external/Tokemak.sol";

interface IOperator {
    /// @notice The core reactor contract that holds the assets.
    function recycler() external view returns (address);
    /// @notice The underlying TOKE token.
    function underlying() external view returns (address);
    /// @notice The derivative tTOKE token.
    function derivative() external view returns (address);
    /// @notice The Tokemak voting contract.
    function onchainvote() external view returns (address);
    /// @notice The Tokemak rewards contract.
    function rewards() external view returns (address);

    /// @notice The recipient of the management fee.
    function feeTo() external view returns (address);
    /// @notice The management fee.
    function fee() external view returns (uint256);
    /// @notice Accepted reactor keys that this contract can vote with.
    function reactorKeys(bytes32 reactorKey) external view returns (bool);

    /// @notice Sets the management fee to.
    function setFeeTo(address feeTo_) external;
    /// @notice Sets the management fee.
    function setFee(uint256 fee_) external;
    /// @notice Sets a reactor key as vaild/invalid.
    function setReactorKey(bytes32 reactorKey, bool value) external;
    /// @notice Claims TOKE, deposits TOKE for tTOKE, fills an `epoch` and creates an new epoch with
    /// the a `deadline` - all in one transaction.
    /// @dev A convenience function for the admin.
    function rollover(
        Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 epoch,
        uint32 deadline
    ) external;
    /// @notice Claims- and stakes the token rewards to compound the assets.
    function compound(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;
    /// @notice Deposit TOKE for Recycler.
    function claim(
        Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 claimed, uint256 fees);
    /// @notice Deposit TOKE for tTOKE for the Recycler.
    function deposit(uint256 amount) external;
    /// @notice Approves the tTOKE to pull TOKE tokens from this contract.
    /// @dev This is required because the tTOKE contract pulls fund using allowance to stake TOKE.
    /// If not called before e.g. `deposit`, `compound` or `posteriori`, then the call will revert.
    function prepare(uint256 amount) external;
    /// @notice Vote on Tokemak reactors using the Recycler.
    /// @dev Each reactor key will be checked against a mapping to see if it's valid.
    function vote(UserVotePayload calldata data) external;
}
