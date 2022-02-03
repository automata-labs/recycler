// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";
import "yield-utils-v2/token/IERC2612.sol";

import "./interfaces/ICallback.sol";
import "./interfaces/IRecycler.sol";
import "./libraries/data/Buffer.sol";
import "./libraries/data/Coin.sol";
import "./libraries/data/Epoch.sol";
import "./libraries/data/Share.sol";
import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/Revert.sol";
import "./libraries/SafeTransfer.sol";

/// @title Recycler
contract Recycler is IRecycler, Auth {
    using Buffer for Buffer.Data;
    using Cast for uint256;
    using Coin for uint256;
    using Epoch for Epoch.Data;
    using SafeTransfer for address;
    using Share for uint256;

    /// @notice Throws when trying to mint when a buffer still exists and cannot be ticked/poked.
    error BufferExists();
    /// @notice Throws when permit deadline has expired.
    error DeadlineExpired();
    /// @notice Throws when trying to fill an epoch with a prev-sibling that's not filled.
    error Discontinuity();
    /// @notice Throws when minting on an latest epoch that's dead or filled.
    error EpochExpired();
    /// @notice Throws there's an insufficient amount from a transfer pull request.
    error InsufficientTransfer();
    /// @notice Throws when conversion to shares gives zero.
    error InsufficientExchange();
    /// @notice Throws when the epoch parameters is invalid (0).
    error InvalidEpoch();
    /// @notice Throws when the permit signature is invalid.
    error InvalidSignature();
    /// @notice Throws when the max capacity is exceeded.
    error OverflowCapacity();
    /// @notice Throws when an amount parameter is less than dust.
    error ParameterDust();
    /// @notice Throws when an amount parameter is zero.
    error ParameterZero();
    /// @notice Throws when the selector is not matchable.
    error UndefinedSelector();

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
    uint256 public dust;
    /// @notice The max capacity of the vault (in tTOKE).
    uint256 public capacity;
    /// @notice The current epoch id.
    uint256 public cursor;
    /// @notice The epochs to batch together deposits and share issuances.
    mapping(uint256 => Epoch.Data) public epochs;

    /// @notice The initial chain id set at deployment.
    uint256 private immutable INITIAL_CHAIN_ID;
    /// @notice The initial domain separator set at deployment.
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    /// @notice Converts an account's buffer into shares if the buffer's epoch has been filled -
    ///     otherwise the function does nothing.
    modifier tick(address account) {
        _tick(account);
        _;
    }

    constructor(address coin_, uint256 dust_) {
        coin = coin_;
        dust = dust_;

        capacity = type(uint256).max;
        epochs[0].filled = true;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /// @notice The permit typehash.
    function PERMIT_TYPEHASH() public pure returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }

    /// @notice The domain separator.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID
            ? INITIAL_DOMAIN_SEPARATOR
            : computeDomainSeparator();
    }

    /// @inheritdoc IERC20Metadata
    function name() public pure returns (string memory) {
        return "(Re)cycle Staked Tokemak";
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external pure returns (string memory) {
        return "(re)tTOKE";
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @dev Override to change version.
    function version() public pure returns (string memory) {
        return "1";
    }

    /// @inheritdoc IERC20
    /// @dev Returns the total amount of active- and buffering coins.
    function totalSupply() external view returns (uint256) {
        return IERC20(coin).balanceOf(address(this));
    }

    /// @inheritdoc IRecycler
    function totalCoins() public view returns (uint256) {
        return IERC20(coin).balanceOf(address(this)) - totalBuffer;
    }

    /// @inheritdoc IERC20
    /// @dev Returns only the number of active coins (i.e. not including buffered coins).
    function balanceOf(address account) external view returns (uint256) {
        uint256 shares = bufferOf[account].toShares(epochs) + sharesOf[account];
        return shares.toCoins(totalCoins(), totalShares);
    }

    /// @inheritdoc IRecycler
    function queuedOf(address account) external view returns (uint256) {
        return bufferOf[account].toQueued(epochs);
    }

    /// @inheritdoc IRecycler
    function epochOf(uint256 index) external view returns (Epoch.Data memory) {
        return epochs[index];
    }

    /// @inheritdoc IRecycler
    function bufferAs(address account) external view returns (Buffer.Data memory) {
        return bufferOf[account];
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 coins)
        external
        noauth
        tick(msg.sender)
        returns (bool)
    {
        _transfer(msg.sender, to, coins);

        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 coins)
        external
        noauth
        tick(from)
        returns (bool)
    {
        _decreaseAllowance(from, coins);
        _transfer(msg.sender, to, coins);

        return true;
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 coins)
        external
        noauth
        returns (bool)
    {
        _approve(msg.sender, spender, coins);

        return true;
    }

    /// @inheritdoc IERC2612
    function permit(
        address owner,
        address spender,
        uint256 coins,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        noauth
    {
        if (deadline < block.timestamp)
            revert DeadlineExpired();

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        coins,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address signer = ecrecover(hash, v, r, s);

        if (signer == address(0) || signer != owner)
            revert InvalidSignature();

        _approve(owner, spender, coins);
    }

    /**
     * Actions
     */

    function set(bytes4 selector, bytes memory data)
        external
        auth
    {
        if (selector == IRecycler.dust.selector)
            dust = abi.decode(data, (uint256));
        else if (selector == IRecycler.capacity.selector)
            capacity = abi.decode(data, (uint256));
        else
            revert UndefinedSelector();
    }

    /// @inheritdoc IRecycler
    function next(uint32 deadline)
        external
        auth
        returns (uint256 id)
    {
        epochs[(id = ++cursor)].deadline = deadline;
    }

    /// @inheritdoc IRecycler
    function poke(address account)
        external
        noauth
        returns (uint256)
    {
        return _tick(account);
    }

    /// @inheritdoc IRecycler
    function mint(address to, uint256 buffer, bytes memory data)
        external
        noauth
        tick(to)
    {
        if (buffer == 0 || buffer < dust)
            revert ParameterDust();

        uint256 balance = _balance(coin);

        if (balance + buffer > capacity)
            revert OverflowCapacity();

        if (epochs[cursor].filled || epochs[cursor].deadline < _blockTimestamp())
            revert EpochExpired();

        if (bufferOf[to].amount > 0 && bufferOf[to].epoch != cursor)
            revert BufferExists();

        // pull coins
        ICallback(msg.sender).mintCallback(data);
        _verify(balance + buffer);

        // update state
        epochs[cursor].amount += buffer.u104();
        totalBuffer += buffer;
        bufferOf[to].epoch = cursor.u32();
        bufferOf[to].amount += buffer.u224();

        emit Transfer(address(0), to, buffer);
    }

    /// @inheritdoc IRecycler
    function burn(address from, address to, uint256 coins)
        external
        noauth
        tick(from)
        returns (uint256 shares)
    {
        if (coins == 0)
            revert ParameterDust();

        _decreaseAllowance(from, coins);
        shares = coins.toShares(totalShares, totalCoins());

        if (shares == 0)
            revert InsufficientExchange();

        totalShares -= shares;
        sharesOf[from] -= shares;
        coin.safeTransfer(to, coins);

        emit Transfer(from, address(0), coins);
    }

    /// @inheritdoc IRecycler
    function exit(address from, address to, uint256 buffer)
        external
        noauth
        tick(from)
    {
        if (buffer == 0)
            revert ParameterZero();

        _decreaseAllowance(from, buffer);
        epochs[bufferOf[from].epoch].amount -= buffer.u104();
        totalBuffer -= buffer;
        bufferOf[to].amount -= buffer.u224();

        if (bufferOf[from].amount == 0)
            delete bufferOf[from];

        coin.safeTransfer(to, buffer);

        emit Transfer(from, address(0), buffer);
    }

    /// @inheritdoc IRecycler
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

    /// @inheritdoc IRecycler
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
     * Previews
     */

    function previewMint() external view returns (uint256) {}

    function previewBurn() external view returns (uint256) {}

    /**
     * ERC-20 internal
     */
    
    /// @notice Computes the domain seprator.
    function computeDomainSeparator() internal virtual view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes(version())),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Internal transfer function that takes coins as parameter and modifies shares.
    function _transfer(address from, address to, uint256 coins) internal {
        uint256 shares = coins.toShares(totalShares, totalCoins());
        sharesOf[from] -= shares;
        sharesOf[to] += shares;
        emit Transfer(msg.sender, to, coins);
    }

    /// @notice Decreases allowance - useful for burning, exiting, etc.
    function _decreaseAllowance(address from, uint256 coins) internal {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max) {
                _approve(from, msg.sender, allowed - coins);
            }
        }
    }

    /// @notice Helper approve function.
    function _approve(address owner, address spender, uint256 coins) internal {
        allowance[owner][spender] = coins;
        emit Approval(owner, spender, coins);
    }

    /**
     * Recycler internal
     */

    /// @notice Ticks an account - used for the `tick` modifier.
    function _tick(address account) internal returns (uint256 shares) {
        Buffer.Data memory buffer = bufferOf[account];

        if (buffer.epoch > 0 && epochs[buffer.epoch].filled) {
            shares = buffer.toShares(epochs);

            if (shares == 0)
                shares = buffer.amount;

            sharesOf[account] += shares;
            delete bufferOf[account];
        }
    }

    /// @notice Verify that funds has been pulled.
    /// @dev Used in conjunction with callbacks.
    function _verify(uint256 expected) internal view {
        if (_balance(coin) < expected) {
            revert InsufficientTransfer();
        }
    }

    /// @notice The balance of a token for this contract.
    function _balance(address token_) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token_.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && returndata.length >= 32);
        balance = abi.decode(returndata, (uint256));
    }

    /// @notice Returns the block timestamp casted to `uint32`.
    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }
}
