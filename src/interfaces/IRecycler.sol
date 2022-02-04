// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";
import "yield-utils-v2/token/IERC2612.sol";

import "../libraries/data/Buffer.sol";
import "../libraries/data/Epoch.sol";

interface IRecycler is IERC20, IERC20Metadata, IERC2612 {
    /// @notice The total amount of shares issued.
    function totalShares() external view returns (uint256);
    /// @notice The total amount of tokens being buffered into shares.
    function totalBuffer() external view returns (uint256);
    /// @notice The mapping for keeping track of shares that each account has.
    function sharesOf(address account) external view returns (uint256);
    /// @notice The mapping for keeping track of buffered tokens.
    function bufferOf(address account) external view returns (uint32 epoch, uint224 amount);
    /// @notice The mapping for allowance.
    function allowance(address owner, address spender) external view returns (uint256);
    /// @notice The mapping for nonces.
    function nonces(address owner) external view returns (uint256);

    /// @notice The staked Tokemak token.
    function coin() external view returns (address);
    /// @notice The staked Tokemak token.
    function dust() external view returns (uint256);
    /// @notice The max capacity of the vault (in tTOKE).
    function capacity() external view returns (uint256);
    /// @notice The current epoch id.
    function cursor() external view returns (uint256);
    /// @notice The current epoch id.
    function epochs(uint256 epoch) external view returns (
        uint32 deadline,
        uint104 amount,
        uint104 shares,
        bool filled
    );

    /// @notice The permit typehash used for `permit`.
    function PERMIT_TYPEHASH() external view returns (bytes32);
    /// @notice Returns the domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the total amount of active coins.
    function totalCoins() external view returns (uint256);
    /// @notice Returns the amount of current buffered coins.
    function queuedOf(address account) external view returns (uint256);
    /// @notice Returns the epoch at `index` as a struct.
    function epochOf(uint256 index) external view returns (Epoch.Data memory);
    /// @notice Returns the buffer of `account` as a struct.
    function bufferAs(address account) external view returns (Buffer.Data memory);

    /// @notice Returns whether the cycle is rolling over or not.
    function rotating() external view returns (bool);
    /// @notice Returns a boolean on mint status.
    /// @dev If false - then the given `mint` call will revert.
    /// Could be due to cycle rollover, deadline or other reasons.
    function mintable(address to, uint256 buffer) external view returns (uint256);
    /// @notice Returns the status and burn amount.
    /// @dev If false - then a `burn` call will revert.
    /// Could be due to cycle rollover, deadline or other reasons.
    function burnable(address from, uint256 coins) external view returns (bool, uint256 shares);

    /// @notice Fast-forward to next epoch.
    /// @dev A new epoch can be created without the previous being filled.
    function next(uint32 deadline) external returns (uint256 id);
    /// @notice Converts an account's buffer into shares if the buffer's epoch has been filled -
    ///     otherwise the function does nothing.
    function poke(address account) external returns (uint256);
    /// @notice Deposit buffered coins at a the cursor's epoch.
    /// @dev The buffered coins turns into shares when the epoch has been filled using `fill`.
    function mint(address to, uint256 buffer, bytes memory data) external;
    /// @notice Burn buffered-shares and shares to get back the underlying coin.
    function burn(address from, address to, uint256 coins) external returns (uint256 shares);
    /// @notice Exit the recycler without earning any rewards.
    /// @dev Can be used if the epochs never gets filled by a manager/admin.
    function exit(address from, address to, uint256 buffer) external;
    /// @notice Fill an epoch with shares (iff the previous epoch is already filled).
    function fill(uint256 epoch) external returns (uint256 shares);
    /// @notice Execute arbitrary calls.
    /// @dev Used for e.g. claiming and voting.
    function execute(
        address[] calldata targets,
        bytes[] calldata datas
    ) external returns (bytes[] memory results);
}
