// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libraries/data/Balance.sol";
import "./libraries/data/Epoch.sol";
import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/ERC20Restricted.sol";
import "./libraries/Lock.sol";
import "./libraries/Pause.sol";
import "./libraries/SafeTransfer.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/ICallback.sol";
import "./interfaces/ISequencer.sol";
import "./interfaces/IReactor.sol";

/// @title Sequencer
contract Sequencer is ISequencer, ERC20Restricted, Auth, Pause, Lock {
    using Cast for uint256;
    using Cast for uint128;
    using SafeTransfer for address;

    /// @notice Emitted when tokens are joined into shares.
    event Joined(address indexed sender);
    /// @notice Emitted when an epoch is called to be filled.
    event Filled(address indexed sender, uint256 idx);
    /// @notice Emitted when an epoch is created.
    event EpochCreated(uint256 indexed index, uint256 indexed cycle, uint32 deadline);

    /// @notice Thrown when an epoch to be filled that has it's previous neighbour non-filled,
    ///     making the epoch-chain discontinous.
    error Discontinuity();
    /// @notice Thrown when a balance has less than `dust` amount `amount` for any call.
    error Dust();
    /// @notice Thrown when shares are zero in some exchange.
    error InsufficientExchange();
    /// @notice Thrown when balance is empty when a call requires a non-empty balance
    error EmptyBalance();
    /// @notice Thrown when epoch's deadline has expired.
    error EpochExpired();
    /// @notice Thrown when is not filled, so `fill` cannot be called.
    error EpochNotFilled();
    /// @notice Thrown when balance is non-emtpy, for when a balance need to be empty for e.g. `mint`.
    error NonEmptyBalance();
    /// @notice Thrown when the `msg.sender` is unauthorized w.r.t. address.
    error Unauthorized();
    /// @notice Thrown when the epochs array is empty.
    error Undefined();
    /// @notice Thrown when `amount` param is zero.
    error Zero();

    struct LoadCallbackData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    /// @inheritdoc ISequencer
    uint256 public supply;
    /// @inheritdoc ISequencer
    mapping(address => Balance.Data) public balances;

    /// @notice The core reactor contract that holds the assets.
    address public immutable reactor;
    /// @notice The underlying token.
    address public immutable underlying;
    /// @notice The derivative token.
    address public immutable derivative;

    /// @notice The minimum amount of tokens that needs to be queued.
    /// @dev This is to avoid the shares amount from reverting when filling.
    uint256 public dust;
    /// @dev The epochs - cannot be discontinuous.
    Epoch.Data[] public epochs;

    constructor(
        address reactor_,
        address underlying_,
        address derivative_,
        uint256 dust_
    ) ERC20Restricted(
        string(abi.encodePacked("Sequencing ", IERC20Metadata(reactor_).name())),
        string(abi.encodePacked("S", IERC20Metadata(reactor_).symbol())),
        18
    ) {
        reactor = reactor_;
        underlying = underlying_;
        derivative = derivative_;
        dust = dust_;
    }

    /**
     * View
     */

    /// @inheritdoc IERC20
    function totalSupply() external view override(ERC20Restricted, IERC20) returns (uint256) {
        return supply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view override(ERC20Restricted, IERC20) returns (uint256) {
        return balances[account].amount;
    }

    /// @inheritdoc ISequencer
    function cardinality() public view returns (uint256) {
        return epochs.length;
    }

    /// @inheritdoc ISequencer
    function index() public view returns (uint256) {
        if (epochs.length > 0)
            return epochs.length - 1;
        else
            revert Undefined();
    }

    /// @inheritdoc ISequencer
    function epoch() external view returns (Epoch.Data memory) {
        return epochs[epochs.length - 1];
    }

    /// @inheritdoc ISequencer
    function epochAt(uint256 idx) external view returns (Epoch.Data memory) {
        return epochs[idx];
    }

    /**
     * Core
     */

    /// @inheritdoc ISequencer
    function push(uint256 currentCycle, uint32 deadline)
        external
        lock
        auth
    {
        epochs.push(Epoch.Data({ deadline: deadline, tokens: 0, shares: 0, filled: false }));
        emit EpochCreated(epochs.length - 1, currentCycle, deadline);
    }

    /// @inheritdoc ISequencer
    function mint(address to, uint256 amount)
        external
        lock
        noauth
        playback
    {
        if (amount == 0)
            revert Zero();

        if (epochs[index()].deadline < _blockTimestamp())
            revert EpochExpired();

        if (balances[to].amount + amount < dust)
            revert Dust();

        // account will have to `join` first to empty the balance
        // each balance can only hold one instance of an epoch deposit
        if (!(balances[to].idx == index() || balances[to].amount == 0))
            revert NonEmptyBalance();

        IReactor(reactor).load(amount, abi.encode(LoadCallbackData({
            token: derivative,
            payer: msg.sender,
            payee: reactor,
            amount: amount
        })));

        supply += amount;
        epochs[index()].tokens += amount.u104();
        balances[to].idx = (index()).u32();
        balances[to].amount += amount.u128();

        emit Transfer(address(0), to, amount);
    }

    /// @inheritdoc ISequencer
    function burn(address to, uint256 amount)
        external
        lock
        noauth
    {
        if (amount == 0)
            revert Zero();

        if (balances[msg.sender].amount == 0)
            revert EmptyBalance();
        
        if (0 < balances[msg.sender].amount && balances[msg.sender].amount < dust)
            revert Dust();

        uint256 idx = balances[msg.sender].idx;

        supply -= amount;
        epochs[idx].tokens -= amount.u104();
        balances[msg.sender].amount -= amount.u224();

        if (balances[msg.sender].amount == 0)
            delete balances[msg.sender];

        if (!epochs[idx].filled) {
            IReactor(reactor).unload(to, amount);
        } else {
            // this path can be used to retrieve sequencing tokens that are stuck when shares are zero.
            // should not happen if `dust` is set sufficiently high
            address[] memory targets = new address[](1);
            bytes[] memory datas = new bytes[](1);
            targets[0] = derivative;
            datas[0] = abi.encodeWithSelector(IERC20.transfer.selector, to, amount);

            IReactor(reactor).execute(targets, datas);
        }

        emit Transfer(msg.sender, address(0), amount);
    }

    /// @inheritdoc ISequencer
    function fill(uint256 idx)
        external
        lock
        auth
    {
        // check that previous epoch has been filled
        if (idx > 0 && !epochs[idx - 1].filled)
            revert Discontinuity();
        
        uint256 shares = IReactor(reactor).mint(address(this), epochs[idx].tokens);
        epochs[idx].shares = shares.u104();
        epochs[idx].filled = true;

        emit Filled(msg.sender, idx);
    }

    /// @inheritdoc ISequencer
    function join(address to)
        external
        lock
        noauth
        returns (uint256 shares)
    {
        uint256 idx = balances[msg.sender].idx;
        uint256 amount = balances[msg.sender].amount;

        // check that epoch has been filled with shares
        if (!epochs[idx].filled)
            revert EpochNotFilled();

        shares = amount * epochs[idx].shares / epochs[idx].tokens;

        // if shares are zero, the sequencing tokens are stuck
        // should not happen if `dust` is set sufficiently high
        if (shares == 0)
            revert InsufficientExchange();
        
        supply -= amount;
        delete balances[msg.sender];
        reactor.safeTransferFrom(address(this), to, shares);

        emit Joined(msg.sender);
    }

    /**
     * Authorization-only
     */

    function loadCallback(bytes memory data)
        external
    {
        // only reactor can pull funds
        // this is to load the tokens into the buffer to prepare for the next cycle
        if (msg.sender != reactor)
            revert Unauthorized();
            
        LoadCallbackData memory decoded = abi.decode(data, (LoadCallbackData));
        decoded.token.safeTransferFrom(decoded.payer, decoded.payee, decoded.amount);
    }

    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }
}
