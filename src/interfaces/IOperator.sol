// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/external/Tokemak.sol";

interface IOperator {
    /// @notice The core reactor contract that holds the assets.
    function reactor() external view returns (address);

    /// @notice The underlying token.
    function underlying() external view returns (address);

    /// @notice The derivative token.
    function derivative() external view returns (address);

    /// @notice The OnChainVoteL1 contract from Tokemak.
    function onchainvote() external view returns (address);

    /// @notice The Rewards contract from Tokemak.
    function rewards() external view returns (address);

    /// @notice The RewardsHash contract from Tokemak.
    function rewardsHash() external view returns (address);

    /// @notice Approves the tTOKE to pull TOKE tokens from this contract.
    /// @dev If not called before `compound`, then `compound` will revert.
    function prepare(uint256 amount) external;

    /// @notice Claims- and stakes the token rewards to compound the assets.
    function compound(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice Routes a `vote` call to reactor.
    function vote(UserVotePayload calldata data) external;

    /// @notice Routes a `claim` call to reactor.
    function claim(Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice Routes a `deposit` call to reactor.
    function deposit(uint256 amount) external;
}
