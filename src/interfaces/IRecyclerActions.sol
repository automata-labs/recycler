// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./external/IOnChainVoteL1.sol";
import "./external/IRewards.sol";

interface IRecyclerActions {
        /// @notice Sets the name.
    /// @param name_ The new name to be set.
    function setName(string memory name_) external;
    /// @notice Sets the maintainer.
    /// @param maintainer_ The new maintainer that receives the fee.
    function setMaintainer(address maintainer_) external;
    /// @notice Sets the maintainer fee.
    /// @dev The fee is capped by `CAP_FEE`.
    /// @param fee_ The new fee to be set.
    function setFee(uint256 fee_) external;
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

    /// @notice Claims TOKE, deposits TOKE for tTOKE, fills an `epoch` and creates an new epoch with
    /// the a `deadline` - all in one transaction.
    /// @dev A convenience function for the admin.
    function rollover(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 epoch,
        uint32 deadline
    ) external;
    /// @notice Claims- and stakes the token rewards to compound the assets.
    function cycle(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) external;
    /// @notice Deposit TOKE for Recycler.
    function claim(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    /// @notice Deposit TOKE for tTOKE for the Recycler.
    function stake(uint256 amount) external;
    /// @notice Approves the tTOKE to pull TOKE tokens from this contract.
    /// @dev This is required because the tTOKE contract pulls fund using allowance to stake TOKE.
    /// If not called before e.g. `deposit`, `compound` or `posteriori`, then the call will revert.
    function prepare(uint256 amount) external;
    /// @notice Vote on Tokemak reactors using the Recycler.
    /// @dev Each reactor key will be checked against a mapping to see if it's valid.
    function vote(IOnChainVoteL1.UserVotePayload calldata data) external;
    /// @notice Fast-forward to next epoch.
    /// @dev A new epoch can be created without the previous being filled.
    /// @param deadline The deadline in unix timestamp.
    /// @return id The epoch id of the created epoch.
    function next(uint32 deadline) external returns (uint256 id);
    /// @notice Fill an epoch with shares (iff the previous epoch is already filled).
    /// @param epoch The epoch id to fill.
    /// @return shares The amount of shares for the epoch `epoch`.
    function fill(uint256 epoch) external returns (uint256 shares);

    /// @notice Execute arbitrary calls.
    /// @dev Used for e.g. claiming and voting.
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external returns (bytes[] memory results);
}
