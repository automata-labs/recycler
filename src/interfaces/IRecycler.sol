// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";
import "yield-utils-v2/token/IERC2612.sol";

import "../libraries/data/Buffer.sol";
import "../libraries/data/Epoch.sol";

interface IRecycler is IERC20, IERC20Metadata, IERC2612 {
    /// @notice The staked Tokemak token.
    function coin() external view returns (address);
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
    /// @notice The mapping for allowance.
    /// @param owner The address to view allowance for.
    /// @param spender The address to view the owner's allowance against.
    /// @return The allowance of `owner` for `spender`.
    function allowance(address owner, address spender) external view returns (uint256);
    /// @notice The mapping for nonces.
    /// @param owner The address to check the nonce value of.
    /// @return The next nonce value.
    function nonces(address owner) external view returns (uint256);

    /// @notice The permit typehash used for `permit`.
    function PERMIT_TYPEHASH() external view returns (bytes32);
    /// @notice Returns the domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the total amount of active coins.
    function totalCoins() external view returns (uint256);
    /// @notice Returns the amount of current buffered coins.
    /// @param account The address of an account.
    /// @return The amount of tokens being buffered/queued. While `bufferOf` can show an amount if
    /// it has not been poked, `queuedOf` will show a updated value. E.g., if `bufferOf.amount` is a
    /// non-zero value, but the epoch has been filled, then `queuedOf` will return zero.
    function queuedOf(address account) external view returns (uint256);
    /// @notice Returns the epoch as a struct.
    /// @dev Convenience function.
    /// @param epoch The epoch id.
    /// @return The epoch as a struct.
    function epochAs(uint256 epoch) external view returns (Epoch.Data memory);
    /// @notice Returns the buffer of `account` as a struct.
    /// @dev Convenience function.
    /// @param account The address of an account.
    /// @return The buffer as a struct.
    function bufferAs(address account) external view returns (Buffer.Data memory);

    /// @notice Returns whether the cycle is rolling over or not.
    function rotating() external view returns (bool);

    /// @notice Set the dust value. Minimum amount of tokens required to `mint`.
    /// @param dust_ The dust amount.
    function setDust(uint256 dust_) external;
    /// @notice Set the capacity value.
    /// @param capacity_ The capacity amount.
    function setCapacity(uint256 capacity_) external;
    /// @notice Set the deadline for an epoch.
    /// @param epoch The epoch id.
    /// @param deadline The deadline in unix timestamp.
    function setDeadline(uint256 epoch, uint32 deadline) external;
    /// @notice Fast-forward to next epoch.
    /// @dev A new epoch can be created without the previous being filled.
    /// @param deadline The deadline in unix timestamp.
    /// @return id The epoch id of the created epoch.
    function next(uint32 deadline) external returns (uint256 id);
    /// @notice Converts an account's buffer into shares if the buffer's epoch has been filled -
    /// otherwise the function does nothing.
    /// @dev The poke function should never revert. If no shares was created, then it'll return zero.
    /// @param account The address of an account.
    /// @return The amount of shares created from the poke.
    function poke(address account) external returns (uint256);
    /// @notice Deposit buffered coins at a the cursor's epoch.
    /// @dev The buffered coins turns into shares when the epoch has been filled using `fill`.
    /// @param to The address that receives the buffered amount.
    /// @param buffer The amount of tokens to buffer/queue.
    /// @param data The callback data - expects to be used to transfer the tokens to pass a check.
    function mint(address to, uint256 buffer, bytes memory data) external;
    /// @notice Burn buffered-shares and shares to get back the underlying coin.
    /// @dev The burn function is a 1:1 burning function.
    /// @param from The address of the account to burn from.
    /// @param to The address of the account that receives the tokens.
    /// @param coins The amount of tokens to burn, to get the underlying.
    /// @return shares The amount of shares burned.
    function burn(address from, address to, uint256 coins) external returns (uint256 shares);
    /// @notice Quit the recycler without earning any rewards.
    /// @dev Can be used if the epochs never gets filled by a manager/admin.
    /// @dev The quit function is a 1:1 burning function.
    /// @param from The address of the account to quit from.
    /// @param to The address of the account that receives the tokens.
    /// @param buffer The amount of tokens to quit with, to get the underlying.
    function quit(address from, address to, uint256 buffer) external;
    /// @notice Fill an epoch with shares (iff the previous epoch is already filled).
    /// @param epoch The epoch id to fill.
    /// @return shares The amount of shares for the epoch `epoch`.
    function fill(uint256 epoch) external returns (uint256 shares);
    // /// @notice Execute arbitrary calls.
    // /// @dev Used for e.g. claiming and voting.
    // function execute(
    //     address[] calldata targets,
    //     bytes[] calldata datas
    // ) external returns (bytes[] memory results);
}
