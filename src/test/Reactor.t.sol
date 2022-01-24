// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../Reactor.sol";
import "./mocks/ERC20Mock.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract SequencerStorageMock {
    Reactor public reactor;
    address public token;
}

contract SequencerMock is SequencerStorageMock {
    struct PaymentData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    constructor(Reactor reactor_, address token_) {
        reactor = reactor_;
        token = token_;
    }

    function load(uint256 amount) public {
        bytes memory data = abi.encode(
            PaymentData({
                token: token,
                payer: msg.sender,
                payee: address(reactor),
                amount: amount
            })
        );

        reactor.load(amount, data);
    }

    function loadCallback(bytes memory data) public {
        PaymentData memory decoded = abi.decode(data, (PaymentData));

        IERC20(decoded.token).transferFrom(decoded.payer, decoded.payee, decoded.amount);
    }
}

contract SequencerRevertMock is SequencerStorageMock {
    constructor(Reactor reactor_, address token_) {
        reactor = reactor_;
        token = token_;
    }

    function load(uint256 amount) public {
        reactor.load(amount, abi.encode(0));
    }

    function loadCallback(bytes memory data) public {}
}

contract User {}

contract ReactorTest is DSTest, Vm, Utilities {
    Reactor public reactor;
    SequencerMock public sequencer;
    SequencerRevertMock public sequencerRevert;
    User public user0;

    function setUp() public {
        reactor = new Reactor(address(tokeVotePool), 0);
        sequencer = new SequencerMock(reactor, address(tokeVotePool));
        sequencerRevert = new SequencerRevertMock(reactor, address(tokeVotePool));
        user0 = new User();

        reactor.allow(address(sequencer));
        reactor.allow(address(sequencerRevert));

        tokeVotePool.approve(address(sequencer), type(uint256).max);
        tokeVotePool.approve(address(sequencerRevert), type(uint256).max);
    }

    function testConstructor() public {
        assertEq(reactor.name(), "Automata TokemakTokePool");
        assertEq(reactor.symbol(), "AtToke");
        assertEq(reactor.decimals(), 18);
        assertEq(reactor.dust(), 0);
    }

    /**
     * `load`
     */

    function testLoad() public {
        mint(address(this), 1e18);

        assertEq(tokeVotePool.balanceOf(address(reactor)), 0);
        assertEq(reactor.buffer(), 0);
        assertEq(reactor.totalSupply(), 0);

        sequencer.load(1e18);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 1e18);
        assertEq(reactor.buffer(), 1e18);
        assertEq(reactor.totalSupply(), 0);
    }

    function testLoadInsufficientTransferRevert() public {
        mint(address(this), 1e18);
        expectRevert(abi.encodeWithSignature("InsufficientTransfer()"));
        sequencerRevert.load(1e18 + 1);
    }

    function testLoadAuthRevert() public {
        reactor.deny(address(sequencer));
        expectRevert("Denied");
        sequencer.load(1e18);
    }

    /**
     * `unload`
     */

    function testUnload() public {
        mint(address(this), 1e18);

        sequencer.load(1e18);
        reactor.unload(address(user0), 3e17);
        assertEq(reactor.buffer(), 7e17);
        assertEq(tokeVotePool.balanceOf(address(user0)), 3e17);

        reactor.unload(address(user0), 7e17);
        assertEq(reactor.buffer(), 0);
        assertEq(tokeVotePool.balanceOf(address(user0)), 1e18);
    }

    function testUnloadInsufficientRevert() public {
        mint(address(this), 1e18);

        sequencer.load(1e18);
        expectRevert(abi.encodeWithSignature("InsufficientBuffer()"));
        reactor.unload(address(user0), 1e18 + 1);
    }

    function testUnloadAuthRevert() public {
        reactor.deny(address(this));
        expectRevert("Denied");
        reactor.unload(address(this), 0);
    }

    /**
     * `mint`
     */

    function testMint() public {
        mint(address(this), 1e18);
        
        sequencer.load(1e18);
        reactor.mint(address(this), 1e18);
        assertEq(reactor.totalSupply(), 1e18);
        assertEq(reactor.balanceOf(address(this)), 1e18);
        assertEq(reactor.buffer(), 0);
    }

    function testMintZeroAmountRevert() public {
        expectRevert(abi.encodeWithSignature("Zero()"));
        reactor.mint(address(this), 0);
    }

    function testMintInsufficientBufferRevert() public {
        mint(address(this), 100_000);
        sequencer.load(100_000);
        reactor.mint(address(this), 100_000);
        mint(address(reactor), 100 * 1e18);

        mint(address(this), 1);
        sequencer.load(1);
        expectRevert(abi.encodeWithSignature("InsufficientExchange()"));
        reactor.mint(address(this), 1);
    }

    function testMintAuthRevert() public {
        mint(address(this), 1);
        sequencer.load(1);

        reactor.deny(address(this));
        expectRevert("Denied");
        reactor.mint(address(this), 1);
    }

    /**
     * `burn`
     */

    function testBurn() public {
        mint(address(this), 1e18);
        sequencer.load(1e18);
        reactor.mint(address(this), 1e18);

        assertEq(reactor.balanceOf(address(this)), 1e18);
        reactor.burn(address(this), address(this), 1e18);
        assertEq(reactor.balanceOf(address(this)), 0);
        assertEq(tokeVotePool.balanceOf(address(this)), 1e18);
    }

    function testBurnWithApproval() public {
        mint(address(this), 1e18);
        sequencer.load(1e18);
        reactor.mint(address(this), 1e18);
        reactor.approve(address(user0), type(uint256).max);
        prank(address(user0));
        reactor.burn(address(this), address(user0), 1e18);
        assertEq(reactor.balanceOf(address(this)), 0);
        assertEq(tokeVotePool.balanceOf(address(user0)), 1e18);
    }

    function testBurnNoAllowanceRevert() public {
        mint(address(this), 1e18);
        sequencer.load(1e18);
        reactor.mint(address(this), 1e18);
        startPrank(address(user0));
        expectRevert("ERC20: Insufficient approval");
        reactor.burn(address(this), address(user0), 1e18);
        stopPrank();
    }
}
