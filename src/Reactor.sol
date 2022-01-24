// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "yield-utils-v2/token/ERC20Permit.sol";
import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";

import "./libraries/external/Tokemak.sol";
import "./libraries/Auth.sol";
import "./libraries/Lock.sol";
import "./libraries/Revert.sol";
import "./libraries/SafeTransfer.sol";
import "./interfaces/external/IOnChainVoteL1.sol";
import "./interfaces/external/IRewards.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/ICallback.sol";

contract Reactor is ERC20Permit, Auth, Lock {
    using SafeTransfer for address;

    /// @notice Reverts when there's insufficient tokens in the buffer.
    error InsufficientBuffer();
    /// @notice Reverts when the exchange rate is zero.
    error InsufficientExchange();
    /// @notice Reverts there's an insufficient amount from a transfer pull request.
    error InsufficientTransfer();
    /// @notice Reverts when the selector is not defined in the `set` function.
    error UndefinedSelector();
    /// @notice Reverts when an amount parameter is zero.
    error Zero();

    /// @notice Emitted when an account burns.
    event Burn(address indexed account, uint256 amount);
    /// @notice Emitted when tokens are loaded into the buffer.
    event Load(address indexed account, uint256 amount);
    /// @notice Emitted when an account mints.
    event Mint(address indexed account, uint256 amount);
    /// @notice Emitted when tokens are unloaded from the buffer.
    event Unload(address indexed account, uint256 amount);

    /// @notice The `tTOKE` token address.
    address public immutable token;
    /// @notice The amount of shares that are locked on a fresh `mint`.
    uint96 public immutable dust;
    /// @notice The amount of tokens that are being queued for the next cycle(s).
    /// @dev This differentiates the queued- and joined token amounts from each other. Because
    ///     rewards are distrbuted every week by the Tokemak Labs team, tokens needs to queued first.
    uint256 public buffer;

    constructor(address token_, uint96 dust_) ERC20Permit(
        string(abi.encodePacked("Automata ", IERC20Metadata(token_).name())),
        string(abi.encodePacked("A", IERC20Metadata(token_).symbol())),
        18
    ) {
        token = token_;
        dust = dust_;
    }

    function load(uint256 amount, bytes memory data)
        external
        lock
        auth
    {
        uint256 balance = _balance(token);
        ICallback(msg.sender).loadCallback(data);

        if (balance + amount > _balance(token))
            revert InsufficientTransfer();

        buffer += amount;
        emit Load(msg.sender, amount);
    }

    function unload(address to, uint256 amount)
        external
        lock
        auth
    {
        if (amount > buffer)
            revert InsufficientBuffer();

        buffer -= amount;
        token.safeTransfer(to, amount);
        emit Unload(msg.sender, amount);
    }

    /// @dev Mints shares from the queued tokens.
    function mint(address to, uint256 amount)
        external
        lock
        auth
        returns (uint256 shares)
    {
        if (amount == 0)
            revert Zero();

        if (amount > buffer)
            revert InsufficientBuffer();

        if (_totalSupply == 0) {
            shares = amount - dust;
            _mint(address(0), dust);
        } else {
            shares = amount * _totalSupply / (_balance(token) - buffer);
        }

        if (shares == 0)
            revert InsufficientExchange();

        buffer -= amount;
        _mint(to, shares);
        emit Mint(msg.sender, amount);
    }

    /// @notice Burn shares to redeem a portion of the reserve.
    function burn(address from, address to, uint256 shares)
        external
        lock
        noauth
        returns (uint256 amount)
    {
        if (shares == 0)
            revert Zero();

        _decreaseAllowance(from, shares);
        amount = shares * (_balance(token) - buffer) / _totalSupply;

        if (amount == 0)
            revert InsufficientExchange();

        _burn(from, shares);
        token.safeTransfer(to, amount);
        emit Burn(msg.sender, amount);
    }

    /// @notice Execute arbitrary calls.
    /// @dev Used mainly for voting, approving, claiming and staking rewards.
    function execute(address[] calldata targets, bytes[] calldata datas)
        external
        lock
        auth
        returns (bytes[] memory results)
    {
        require(targets.length == datas.length, "Mismatch");
        results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            bool success;

            if (targets[i] != address(this)) {
                (success, results[i]) = targets[i].call(datas[i]);
            } else if (targets[i] == address(this)) {
                (success, results[i]) = address(this).delegatecall(datas[i]);
            }

            if (!success) {
                revert(Revert.getRevertMsg(results[i]));
            }
        }
    }

    /**
     * Internal
     */

    function _balance(address token_) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token_.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }
}
