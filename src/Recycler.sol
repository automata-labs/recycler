// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";
import "yield-utils-v2/token/IERC2612.sol";

import "./interfaces/external/IOnChainVoteL1.sol";
import "./interfaces/external/IRewards.sol";
import "./interfaces/external/ITokeVotePool.sol";
import "./interfaces/ICallback.sol";
import "./interfaces/IRecycler.sol";
import "./libraries/data/Buffer.sol";
import "./libraries/data/Coin.sol";
import "./libraries/data/Epoch.sol";
import "./libraries/data/Share.sol";
import "./libraries/Auth.sol";
import "./libraries/Cast.sol";
import "./libraries/Lock.sol";
import "./libraries/Pause.sol";
import "./libraries/Revert.sol";
import "./libraries/SafeTransfer.sol";

/// @title Recycler
contract Recycler is IRecycler, Lock, Auth, Pause {
    using Buffer for Buffer.Data;
    using Cast for uint256;
    using Coin for uint256;
    using Epoch for Epoch.Data;
    using SafeTransfer for address;
    using Share for uint256;

    /// @notice The max fee that can be set.
    uint256 internal constant MAX_FEE = 1e4;
    /// @notice The capped fee at 10%.
    uint256 internal constant CAP_FEE = 1e3;
    /// @notice The internal name variable.
    /// @dev Can be changed.
    string internal _name;

    /// @inheritdoc IRecyclerState
    address public immutable underlying;
    /// @inheritdoc IRecyclerState
    address public immutable derivative;
    /// @inheritdoc IRecyclerState
    address public immutable onchainvote;
    /// @inheritdoc IRecyclerState
    address public immutable rewards;

    /// @inheritdoc IRecyclerState
    uint256 public dust;
    /// @inheritdoc IRecyclerState
    uint256 public capacity;
    /// @inheritdoc IRecyclerState
    uint256 public cursor;
    /// @notice The maintainer of the vault.
    /// @dev Receives the fee when calling `claim`, if non-zero.
    address public maintainer;
    /// @notice The fee
    uint256 public fee;

    /// @inheritdoc IRecyclerState
    uint256 public totalShares;
    /// @inheritdoc IRecyclerState
    uint256 public totalBuffer;
    /// @inheritdoc IRecyclerState
    mapping(address => uint256) public sharesOf;
    /// @inheritdoc IRecyclerState
    mapping(address => Buffer.Data) public bufferOf;
    /// @inheritdoc IRecyclerState
    mapping(uint256 => Epoch.Data) public epochOf;
    /// @inheritdoc IERC20
    mapping(address => mapping(address => uint256)) public allowance;
    /// @inheritdoc IERC2612
    mapping(address => uint256) public nonces;
    /// @inheritdoc IRecyclerState
    mapping(bytes32 => bool) public keys;

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

    constructor(
        address underlying_,
        address derivative_,
        address onchainvote_,
        address rewards_,
        uint256 dust_
    ) {
        if (
            derivative_ == address(0) ||
            underlying_ == address(0) ||
            onchainvote_ == address(0) ||
            rewards_ == address(0)
        ) {
            revert ParameterZero();
        }

        underlying = underlying_;
        derivative = derivative_;
        onchainvote = onchainvote_;
        rewards = rewards_;
        dust = dust_;

        _name = "(Re)cycler Staked Tokemak";
        capacity = type(uint256).max;
        epochOf[0].filled = true;

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
    function name() public view returns (string memory) {
        return _name;
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
    function totalSupply() public view returns (uint256) {
        return IERC20(derivative).balanceOf(address(this));
    }

    /// @inheritdoc IRecyclerStateDerived
    function totalCoins() public view returns (uint256) {
        uint256 balance = IERC20(derivative).balanceOf(address(this));

        if (balance >= totalBuffer) {
            return IERC20(derivative).balanceOf(address(this)) - totalBuffer;
        } else {
            return 0;
        }
    }

    /// @inheritdoc IERC20
    /// @dev Returns only the number of active coins (i.e. not including buffered coins).
    function balanceOf(address account) external view returns (uint256) {
        uint256 shares = bufferOf[account].toShares(epochOf) + sharesOf[account];
        return shares.toCoins(totalCoins(), totalShares);
    }

    /// @inheritdoc IRecyclerStateDerived
    function queuedOf(address account) external view returns (uint256) {
        return bufferOf[account].toQueued(epochOf);
    }

    /// @inheritdoc IRecyclerStateDerived
    function epochAs(uint256 index) external view returns (Epoch.Data memory) {
        return epochOf[index];
    }

    /// @inheritdoc IRecyclerStateDerived
    function bufferAs(address account) external view returns (Buffer.Data memory) {
        return bufferOf[account];
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 coins)
        external
        noauth
        playback
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
        playback
        tick(from)
        returns (bool)
    {
        _decreaseAllowance(from, coins);
        _transfer(from, to, coins);

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
     * View
     */

    /// @inheritdoc IRecyclerStateDerived
    function rotating() external view returns (bool) {
        if (epochOf[cursor].filled || epochOf[cursor].deadline < _blockTimestamp()) {
            return true;
        } else {
            return false;
        }
    }

    /// @inheritdoc IRecyclerStateDerived
    function coinsToShares(uint256 coins) external view returns (uint256) {
        return coins.toShares(totalShares, totalCoins());
    }

    /// @inheritdoc IRecyclerStateDerived
    function sharesToCoins(uint256 shares) external view returns (uint256) {
        return shares.toCoins(totalCoins(), totalShares);
    }

    /**
     * Setters
     */

    /// @inheritdoc IRecyclerActions
    function setName(string memory name_)
        external
        auth
    {
        _name = name_;
        emit SetName(_name);
    }

    /// @inheritdoc IRecyclerActions
    function setMaintainer(address maintainer_)
        external
        auth
    {
        maintainer = maintainer_;
        emit SetMaintainer(maintainer);
    }

    /// @inheritdoc IRecyclerActions
    function setFee(uint256 fee_)
        external
        auth
    {
        if (fee_ > CAP_FEE)
            revert InvalidFee();

        fee = fee_;
        emit SetFee(fee);
    }

    /// @inheritdoc IRecyclerActions
    function setDust(uint256 dust_)
        external
        auth
    {
        dust = dust_;
        emit SetDust(dust);
    }

    /// @inheritdoc IRecyclerActions
    function setCapacity(uint256 capacity_)
        external
        auth
    {
        capacity = capacity_;
        emit SetCapacity(dust);
    }

    function setKey(bytes32 key, bool value)
        external
        auth
    {
        keys[key] = value;
        emit SetKey(key, value);
    }

    /// @inheritdoc IRecyclerActions
    function setDeadline(uint256 epoch, uint32 deadline)
        external
        auth
    {
        if (epoch == 0)
            revert InvalidEpoch();

        epochOf[epoch].deadline = deadline;
        emit SetDeadline(epoch, deadline);
    }

    /**
     * Actions
     */

    /// @inheritdoc IRecyclerActions
    function poke(address account)
        external
        noauth
        lock
        returns (uint256)
    {
        return _tick(account);
    }

    /// @inheritdoc IRecyclerActions
    function mint(address to, uint256 buffer, bytes memory data)
        external
        noauth
        lock
        playback
        tick(to)
    {
        if (buffer == 0 || buffer < dust)
            revert ParameterDust();

        uint256 balance = _balance(derivative);

        if (balance + buffer > capacity)
            revert OverflowCapacity();

        // if a past buffer exists that didn't get cleared by tick, the revert
        // cannot store to queued deposits at once
        if (bufferOf[to].amount > 0 && bufferOf[to].epoch != cursor)
            revert BufferExists();

        // check that current epoch is depositable
        if (epochOf[cursor].filled || epochOf[cursor].deadline < _blockTimestamp())
            revert EpochExpired();

        // pull coins
        ICallback(msg.sender).mintCallback(data);
        _verify(balance + buffer);

        // update state
        epochOf[cursor].amount += buffer.u104();
        totalBuffer += buffer;
        bufferOf[to].epoch = cursor.u32();
        bufferOf[to].amount += buffer.u224();

        emit Transfer(address(0), to, buffer);
        emit Mint(msg.sender, to, buffer);
    }

    /// @inheritdoc IRecyclerActions
    function burn(address from, address to, uint256 coins)
        external
        noauth
        lock
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
        derivative.safeTransfer(to, coins);

        emit Transfer(from, address(0), coins);
        emit Burn(msg.sender, from, to, coins);
    }

    /// @inheritdoc IRecyclerActions
    function quit(address from, address to, uint256 buffer)
        external
        noauth
        lock
        tick(from)
    {
        if (buffer == 0)
            revert ParameterZero();

        _decreaseAllowance(from, buffer);
        epochOf[bufferOf[from].epoch].amount -= buffer.u104();
        totalBuffer -= buffer;
        bufferOf[to].amount -= buffer.u224();

        if (bufferOf[from].amount == 0)
            delete bufferOf[from];

        derivative.safeTransfer(to, buffer);

        emit Transfer(from, address(0), buffer);
        emit Exit(msg.sender, from, to, buffer);
    }

    /**
     * Maintainance
     */

    /// @inheritdoc IRecyclerActions
    function rollover(
        IRewards.Recipient memory recipient,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 epoch,
        uint32 deadline
    )
        external
        auth
    {
        if (epoch == 0)
            revert InvalidEpoch();

        if (deadline == 0)
            revert InvalidDeadline();

        cycle(recipient, v, r, s);
        fill(epoch);
        next(deadline);
    }

    /// @inheritdoc IRecyclerActions
    function cycle(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        public
        auth
    {
        claim(recipient, v, r, s);
        stake(_balance(underlying));
    }

    /// @inheritdoc IRecyclerActions
    function claim(IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s)
        public
        auth
    {
        IRewards(rewards).claim(recipient, v, r, s);
    }

    /// @inheritdoc IRecyclerActions
    function stake(uint256 amount)
        public
        auth
    {
        ITokeVotePool(derivative).deposit(amount);

        // The equation for minting the fee as shares to the maintainer is defined as:
        //
        // fee_percentage = fee / max_fee
        //
        //                        rewards * fee_percentage
        // shares = ---------------------------------------------------- * total_shares
        //           total_supply + rewards - (rewards * fee_percentage)
        //
        // and incorporates a similar behaviour as Lido's [1]. The function must include the rewards
        // that otherwise goes to depositors in the denominator so that the fee sent to the
        // maintainer does not get compounding. So the maintainer's shares can be thought of as a
        // deposit in an epoch, not earning until next cycle.
        //
        // [1]: https://github.com/lidofinance/lido-dao/blob/master/contracts/0.4.24/Lido.sol
        if (fee > 0 && maintainer != address(0)) {
            uint256 fees = (amount * fee) / MAX_FEE;
            uint256 shares;

            if (totalShares == 0 || totalSupply() - fees == 0) {
                shares = fees;
            } else {
                shares = shares = (fees * totalShares) / (totalSupply() - fees);
            }

            totalShares += shares;
            sharesOf[maintainer] += shares;
        }
    }

    /// @inheritdoc IRecyclerActions
    function prepare(uint256 amount)
        external
        auth
    {
        IERC20(underlying).approve(derivative, amount);
    }

    /// @inheritdoc IRecyclerActions
    function vote(IOnChainVoteL1.UserVotePayload calldata data)
        external
        auth
    {
        IOnChainVoteL1(onchainvote).vote(data);
    }

    /// @inheritdoc IRecyclerActions
    function next(uint32 deadline)
        public
        auth
        returns (uint256 id)
    {
        epochOf[(id = ++cursor)].deadline = deadline;
        emit Next(msg.sender, id, deadline);
    }

    /// @inheritdoc IRecyclerActions
    function fill(uint256 epoch)
        public
        auth
        returns (uint256 shares)
    {
        if (epoch == 0)
            revert InvalidEpoch();

        if (!epochOf[epoch - 1].filled)
            revert Discontinuity();

        shares = epochOf[epoch].toShares(totalShares, totalCoins());
        totalShares += shares;
        totalBuffer -= epochOf[epoch].amount;
        epochOf[epoch].shares = shares.u104();
        epochOf[epoch].filled = true;

        emit Fill(msg.sender, epoch, epochOf[epoch].amount, shares);
    }

    /**
     * Miscellaneous
     */

    /// @notice Sweep ERC20 tokens from this contract.
    function sweep(address token, address to)
        external
        lock
        auth
    {
        if (token == derivative || token == underlying)
            revert InvalidToken();

        if (to == address(0))
            revert ParameterZero();

        token.safeTransfer(to, _balance(token));
    }

    /**
     * Upgradeability
     */

    /// @inheritdoc IRecyclerActions
    function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        auth
        returns (bytes[] memory results)
    {
        require(targets.length == datas.length, "Mismatch");
        require(targets.length == values.length, "Mismatch");
        results = new bytes[](targets.length);

        uint256 length = targets.length;
        for (uint256 i = 0; i < length; i++) {
            bool success;

            if (targets[i] != address(this)) {
                (success, results[i]) = targets[i].call{value: values[i]}(datas[i]);
            } else if (targets[i] == address(this)) {
                (success, results[i]) = address(this).delegatecall(datas[i]);
            }

            if (!success) {
                revert(Revert.getRevertMsg(results[i]));
            }
        }
    }

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

        if (buffer.epoch > 0 && epochOf[buffer.epoch].filled) {
            shares = buffer.toShares(epochOf);

            // either first-ever deposit or full-slash
            // if that's the case, fallback to 1:1
            if (shares == 0)
                shares = buffer.amount;

            sharesOf[account] += shares;
            delete bufferOf[account];
        }
    }

    /// @notice Verify that funds has been pulled.
    /// @dev Used in conjunction with callbacks.
    function _verify(uint256 expected) internal view {
        if (_balance(derivative) < expected)
            revert InsufficientTransfer();
    }

    /// @notice The balance of a token for this contract.
    function _balance(address token) internal view returns (uint256 balance) {
        (bool success, bytes memory returndata) = token.staticcall(
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
