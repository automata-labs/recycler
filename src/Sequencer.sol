// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/ERC20Restricted.sol";
import "./libraries/Pause.sol";
import "./libraries/SafeTransfer.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/ICallback.sol";
import "./interfaces/IReactor.sol";

contract Sequencer is ERC20Restricted, Auth, Pause {
    using Cast for uint256;
    using Cast for uint128;
    using SafeTransfer for address;

    event Exited(address indexed sender);
    event Joined(address indexed sender);
    event Filled(address indexed sender, uint256 idx);
    event EpochCreated(uint256 indexed index, uint256 indexed cycle, uint32 deadline);

    error Discontinuity();
    error Dust();
    error InsufficientExchange();
    error EmptyBalance();
    error EpochExpired();
    error EpochNotFilled();
    error NonEmptyBalance();
    error PollEmpty();
    error Unauthorized();
    error Undefined();
    error Zero();

    struct LoadCallbackData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    struct Balance {
        uint32 idx;
        uint224 amount;
    }

    struct Epoch {
        /// @dev The timestamp in which this epoch becomes outdated.
        uint32 deadline;
        /// @dev The total amount of tokens deposited during this epoch (batch of cycles).
        uint104 tokens;
        /// @dev The total shares redeemable by the depositors during this cycle.
        uint104 shares;
        /// @dev If the epoch has been filled with shares.
        bool filled;
    }

    /// @notice The total supply of queued tokens.
    uint256 public supply;
    /// @dev The mapping from address to queued balance.
    mapping(address => Balance) internal balances;

    /// @notice The core reactor contract that holds the assets.
    address public immutable reactor;
    /// @notice The derivative token.
    address public immutable underlying;
    /// @notice The derivative token.
    address public immutable derivative;

    /// @notice The minimum amount of tokens that needs to be queued.
    /// @dev This is to avoid the shares amount from reverting when filling.
    uint256 public dust;
    /// @dev The epochs - can be discontinuous.
    Epoch[] public epochs;

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
    function totalSupply() external view override returns (uint256) {
        return supply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view override returns (uint256) {
        return balances[account].amount;
    }

    function cardinality() public view returns (uint256) {
        return epochs.length;
    }

    function index() public view returns (uint256) {
        if (epochs.length > 0)
            return epochs.length - 1;
        else
            revert Undefined();
    }

    function epoch() external view returns (Epoch memory) {
        return epochs[epochs.length - 1];
    }

    function epochAt(uint256 idx) external view returns (Epoch memory) {
        return epochs[idx];
    }

    /**
     * Core
     */

    function push(uint256 currentCycle, uint32 deadline)
        external
        auth
    {
        epochs.push(Epoch({ deadline: deadline, tokens: 0, shares: 0, filled: false }));
        emit EpochCreated(epochs.length - 1, currentCycle, deadline);
    }

    function mint(address to, uint256 amount)
        external
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

    function burn(address to, uint256 amount)
        external
        noauth
    {
        if (amount == 0)
            revert Zero();

        if (balances[msg.sender].amount == 0)
            revert EmptyBalance();
        
        if (0 < balances[msg.sender].amount && balances[msg.sender].amount < dust)
            revert Dust();

        uint256 idx = balances[msg.sender].idx;
        uint256 shares = amount * epochs[idx].shares / epochs[idx].tokens;

        supply -= amount;
        epochs[idx].tokens -= amount.u104();
        epochs[idx].shares -= shares.u104();
        balances[msg.sender].amount -= amount.u224();

        if (balances[msg.sender].amount == 0)
            delete balances[msg.sender];

        if (!epochs[idx].filled) {
            IReactor(reactor).unload(to, amount);
        } else {
            // this path can be used to retrieve sequencing tokens that are stuck due when shares
            // are zero.
            address[] memory targets = new address[](1);
            bytes[] memory datas = new bytes[](1);
            targets[0] = derivative;
            datas[0] = abi.encodeWithSelector(IERC20.transfer.selector, to, amount);

            IReactor(reactor).execute(targets, datas);
        }

        emit Transfer(msg.sender, address(0), amount);
    }

    /// @notice Claim up until an epoch using a IPFS hash and mint shares for that same epoch.
    function fill(uint256 idx)
        external
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

    /// @notice Burn sequencing tokens to get shares from the reactor.
    function join(address to)
        external
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
