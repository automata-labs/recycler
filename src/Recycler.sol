// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";

import "./libraries/data/Buffer.sol";
import "./libraries/data/Coin.sol";
import "./libraries/data/Epoch.sol";
import "./libraries/data/Share.sol";
import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/Revert.sol";
import "./libraries/SafeTransfer.sol";
import "./interfaces/ICallback.sol";

// not increasing supply as shares are distributed pro rata after a full-cycle
// function exit(address to, uint256 buffer) external returns (bool) {
//     tick(msg.sender);

//     if (buffer == 0)
//         revert ParameterZero();

//     epochs[bufferOf[msg.sender].epoch].amount -= buffer.u104();
//     totalBuffer -= buffer;
//     bufferOf[msg.sender].amount -= buffer.u224();

//     if (bufferOf[msg.sender].amount == 0)
//         delete bufferOf[msg.sender];

//     coin.safeTransfer(to, buffer);

//     return true;
// }
/**
 * ERC-20 actions
 */

// function transfer(address to, uint256 amount) external returns (bool) {
//     tick(msg.sender);
//     return true;
// }

contract Recycler is Auth {
    using Buffer for Buffer.Data;
    using Cast for uint256;
    using Coin for uint256;
    using Epoch for Epoch.Data;
    using SafeTransfer for address;
    using Share for uint256;

    error BufferExists();
    error Discontinuity();
    error EpochExpired();
    /// @notice Reverts there's an insufficient amount from a transfer pull request.
    error InsufficientTransfer();
    /// @notice Throws when conversion to shares gives zero.
    error InsufficientExchange();
    /// @notice Throws when the epoch parameters is invalid (0).
    error InvalidEpoch();
    /// @notice Reverts when an amount parameter is less than dust.
    error ParameterDust();
    /// @notice Reverts when an amount parameter is zero.
    error ParameterZero();

    /// @dev Emitted when coins are moved from one address to another.
    event Transfer(address indexed from, address indexed to, uint256 amount);
    /// @dev Emitted when `approval` or `permit` sets the allowance.
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice The total amount of shares issued.
    uint256 public totalShares;
    /// @notice The total amount of tokens being buffered into shares.
    uint256 public totalBuffer;
    /// @notice The mapping for keeping track of shares that each account has.
    mapping(address => uint256) public sharesOf;
    /// @notice The mapping for keeping track of buffered tokens.
    mapping(address => Buffer.Data) public bufferOf;
    /// @notice The mapping for allowance.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice The mapping for nonces.
    mapping(address => uint256) public nonces;

    /// @notice The staked Tokemak token.
    address public immutable coin;
    /// @notice The minimum amount of tokens that needs to be deposited.
    uint256 public immutable dust;
    /// @notice The current epoch id.
    uint256 public cursor;
    /// @notice The epochs to batch together deposits and share issuances.
    mapping(uint256 => Epoch.Data) public epochs;

    constructor(address coin_, uint256 dust_) {
        coin = coin_;
        dust = dust_;

        epochs[0].filled = true;
    }

    /**
     * ERC-20 derived
     */

    function name() external pure returns (string memory) {
        return "(Re)cycle Staked Tokemak";
    }

    function symbol() external pure returns (string memory) {
        return "(re)tTOKE";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function version() public pure returns (string memory) {
        return "1";
    }

    /// @notice Returns the total amount of active- and buffering coins.
    function totalSupply() external view returns (uint256) {
        return IERC20(coin).balanceOf(address(this));
    }

    /// @notice Returns only the number of active coins (i.e. coins not being buffered).
    function balanceOf(address account) external view returns (uint256) {
        uint256 shares = bufferOf[account].toShares(epochs) + sharesOf[account];
        return shares.toCoins(totalCoins(), totalShares);
    }

    /**
     * Core derived
     */
    
    /// @notice Returns the total amount of active coins.
    function totalCoins() public view returns (uint256) {
        return IERC20(coin).balanceOf(address(this)) - totalBuffer;
    }

    /// @notice Returns the buffer of `account` as a struct.
    function bufferAs(address account) external view returns (Buffer.Data memory) {
        return bufferOf[account];
    }

    /// @notice Returns the epoch at `index` as a struct.
    function epochOf(uint256 index) external view returns (Epoch.Data memory) {
        return epochs[index];
    }

    /**
     * Core actions
     */

    function next(uint32 deadline)
        external
        auth
        returns (uint256 id)
    {
        epochs[(id = ++cursor)].deadline = deadline;
    }

    /// @notice Converts buffer into shares if the buffer's epoch has been filled - otherwise the
    ///     function does nothing.
    function tick(address account)
        public
        noauth
        returns (uint256 shares)
    {
        Buffer.Data memory buffer = bufferOf[account];

        if (buffer.epoch > 0 && epochs[buffer.epoch].filled) {
            shares = buffer.toShares(epochs);

            if (shares == 0)
                shares = buffer.amount;

            sharesOf[account] += shares;
            delete bufferOf[account];
        }
    }

    /// @notice Deposit buffered coins at a the cursor's epoch.
    /// @dev The buffered coins turns into shares when the epoch has been filled using `fill`.
    function mint(address to, uint256 buffer, bytes memory data)
        external
        noauth
    {
        if (buffer == 0 || buffer < dust)
            revert ParameterDust();

        tick(to);

        if (epochs[cursor].filled || epochs[cursor].deadline < _blockTimestamp())
            revert EpochExpired();

        if (bufferOf[to].amount > 0 && bufferOf[to].epoch != cursor)
            revert BufferExists();

        // pull coins
        uint256 balance = _balance(coin);
        ICallback(msg.sender).mintCallback(data);
        _verify(balance + buffer);

        // update state
        epochs[cursor].amount += buffer.u104();
        totalBuffer += buffer;
        bufferOf[to].epoch = cursor.u32();
        bufferOf[to].amount = buffer.u224();

        emit Transfer(address(0), to, buffer);
    }

    function burn(address from, address to, uint256 coins)
        external
        noauth
        returns (uint256 shares)
    {
        if (coins == 0)
            revert ParameterDust();

        tick(from);
        _decreaseAllowance(from, coins);
        shares = coins.toShares(totalShares, totalCoins());

        if (shares == 0)
            revert InsufficientExchange();

        totalShares -= shares;
        sharesOf[from] -= shares;
        coin.safeTransfer(to, coins);

        emit Transfer(from, address(0), coins);
    }

    function fill(uint256 epoch)
        external
        auth
        returns (uint256 shares)
    {
        if (epoch == 0)
            revert InvalidEpoch();

        if (!epochs[epoch - 1].filled)
            revert Discontinuity();

        shares = epochs[epoch].toShares(totalShares, totalCoins());
        totalShares += shares;
        totalBuffer -= epochs[epoch].amount;
        epochs[epoch].shares = shares.u104();
        epochs[epoch].filled = true;
    }

    function execute(address[] calldata targets, bytes[] calldata datas)
        external
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

    function _verify(uint256 expected) internal view {
        if (_balance(coin) < expected) {
            revert InsufficientTransfer();
        }
    }

    function _balance(address token_) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token_.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }

    function _decreaseAllowance(address from, uint amount) internal virtual returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint).max) {
                require(allowed >= amount, "ERC20: Insufficient approval");
                unchecked { _setAllowance(from, msg.sender, allowed - amount); }
            }
        }

        return true;
    }

    function _setAllowance(address owner, address spender, uint amount)
        internal
        virtual
        returns (bool)
    {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);

        return true;
    }

    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }
}
