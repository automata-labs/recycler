// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";

import "../libraries/data/Balance.sol";
import "../libraries/data/Epoch.sol";

interface ISequencer is IERC20 {
    /// @notice The total supply of sequencing tokens.
    function supply() external view returns (uint256);

    /// @notice The mapping from address to sequencing token balance.
    function balances(address account) external view returns (uint32, uint224);

    /// @notice The core reactor contract that holds the assets.
    function reactor() external view returns (address);

    /// @notice The underlying token.
    function underlying() external view returns (address);

    /// @notice The derivative token.
    function derivative() external view returns (address);

    /// @notice The minimum amount of tokens that needs to be queued.
    /// @dev This is to avoid the shares amount from reverting when filling.
    function dust() external view returns (uint256);

    /// @notice The epochs - can be discontinuous.
    function epochs(uint256 idx) external view returns (uint32, uint104, uint104, bool);

    /// @notice Returns the array length of `epochs`.
    function cardinality() external view returns (uint256);

    /// @notice Returns the latest index of `epochs`.
    function index() external view returns (uint256);

    /// @notice Returns the latest epoch.
    function epoch() external view returns (Epoch.Data memory);

    /// @notice Returns the epoch at an index.
    function epochAt(uint256 idx) external view returns (Epoch.Data memory);

    /// @notice Create/start a new epoch.
    function push(uint256 currentCycle, uint32 deadline) external;

    /// @notice Mint sequencing tokens by depositing derivative tokens.
    /// @dev Starts the sequencing process into the reactor.
    function mint(address to, uint256 amount) external;

    /// @notice Burn sequencing tokens to receive the same amount of derivatives back.
    /// @dev Can also be used to rescue sequencing tokens that are stuck for any reasons.
    function burn(address to, uint256 amount) external;

    /// @notice Claim up until an epoch using a IPFS hash and mint shares for that same epoch.
    function fill(uint256 idx) external;

    /// @notice Burn sequencing tokens to get shares from the reactor.
    function join(address to) external returns (uint256 shares);
}
