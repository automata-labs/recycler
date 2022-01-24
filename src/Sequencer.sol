// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/ERC20Restricted.sol";
import "./libraries/Pause.sol";
import "./libraries/SafeTransfer.sol";
import "./interfaces/external/IRewards.sol";
import "./interfaces/external/IRewardsHash.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/ICallback.sol";
import "./interfaces/IReactor.sol";

contract Sequencer is ERC20Restricted, Auth, Pause {
    using Cast for uint256;
    using Cast for uint128;
    using SafeTransfer for address;

    event Joined(address indexed sender);
    event Filled(address indexed sender, uint256 idx);

    error BadEpoch();
    error Dust();
    error InsufficientExchange();
    error EmptyBalance();
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
        /// @dev Hash of the `latestClaimable` IPFS hash.
        bytes32 hash;
        /// @dev The cycle which this epoch was created at.
        uint24 cycle;
        /// @dev The total amount of tokens deposited during this epoch (batch of cycles).
        uint112 tokens;
        /// @dev The total shares redeemable by the depositors during this cycle.
        uint112 shares;
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
    /// @notice The Tokemak rewards contract.
    address public immutable rewards;
    /// @notice The Tokemak cycle hash contract.
    address public immutable rewardsHash;

    /// @notice The minimum amount of tokens that needs to be queued.
    /// @dev This is to avoid the shares amount from reverting when filling.
    uint256 public dust;
    /// @dev The epochs - can be discontinuous.
    Epoch[] public epochs;

    constructor(
        address reactor_,
        address underlying_,
        address derivative_,
        address rewards_,
        address rewardsHash_,
        uint256 dust_
    ) ERC20Restricted(
        string(abi.encodePacked("Sequencing ", IERC20Metadata(reactor_).name())),
        string(abi.encodePacked("S", IERC20Metadata(reactor_).symbol())),
        18
    ) {
        reactor = reactor_;
        underlying = underlying_;
        derivative = derivative_;
        rewards = rewards_;
        rewardsHash = rewardsHash_;
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

    function cursor() public view returns (bytes32) {
        if (epochs.length > 0)
            return epochs[epochs.length - 1].hash;
        else
            return bytes32(0);
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

    function mint(address to, uint256 amount)
        external
        noauth
        playback
    {
        _poll();

        if (amount == 0)
            revert Zero();

        if (amount < dust)
            revert Dust();

        if (epochs[index()].filled)
            revert BadEpoch();

        if (!(balances[to].idx == index() || balances[to].amount == 0))
            revert NonEmptyBalance();

        IReactor(reactor).load(amount, abi.encode(LoadCallbackData({
            token: derivative,
            payer: msg.sender,
            payee: reactor,
            amount: amount
        })));

        supply += amount;
        epochs[index()].tokens += amount.u112();
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

        uint256 shares;
        uint256 idx = balances[msg.sender].idx;

        if (epochs[idx].filled)
            shares = amount * epochs[idx].shares / epochs[idx].tokens;

        supply -= amount;
        epochs[idx].tokens -= amount.u112();
        epochs[idx].shares -= shares.u112();
        balances[msg.sender].amount -= amount.u224();
        IReactor(reactor).unload(to, amount);

        emit Transfer(msg.sender, address(0), amount);
    }

    /// @notice Claim up until an epoch using a IPFS hash and mint shares for that same epoch.
    function fill(uint256 idx)
        external
        auth
    {
        if (idx > 0 && !epochs[idx - 1].filled)
            revert BadEpoch();
        
        uint256 shares = IReactor(reactor).mint(address(this), epochs[idx].tokens);
        epochs[idx].shares = shares.u112();
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

        if (!epochs[idx].filled)
            revert BadEpoch();

        shares = amount * epochs[idx].shares / epochs[idx].tokens;

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
        if (msg.sender != reactor)
            revert Unauthorized();
            
        LoadCallbackData memory decoded = abi.decode(data, (LoadCallbackData));
        decoded.token.safeTransferFrom(decoded.payer, decoded.payee, decoded.amount);
    }

    /**
     * Internal
     */

    /// @dev Should push a new epoch if the observed `latestClaimable` has changed.
    function _poll() internal {
        uint24 cycle = IRewardsHash(rewardsHash).latestCycleIndex().u24();
        (string memory latestClaimable, ) = IRewardsHash(rewardsHash).cycleHashes(cycle);

        if (bytes(latestClaimable).length == 0)
            revert PollEmpty();

        bytes32 hash = keccak256(abi.encodePacked(latestClaimable));

        if (cursor() != hash) {
            epochs.push(Epoch({ hash: hash, cycle: cycle, tokens: 0, shares: 0, filled: false }));
        }
    }
}
