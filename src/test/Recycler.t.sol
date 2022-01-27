// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../libraries/SafeTransfer.sol";
import "../Recycler.sol";
import "./utils/Utilities.sol";

contract RecyclerTest is DSTest, Vm, Utilities {
    Recycler public recycler;

    Manager public manager;
    User public user0;
    User public user1;
    User public user2;

    function assertEq(bool x, bool y) internal {
        if (x != y) {
            emit log("Error: Assertion Failed");
            fail();
        }
    }

    function setUp() public {
        recycler = new Recycler(address(tokeVotePool), 0);
        manager = new Manager(recycler, address(tokeVotePool));
        user0 = new User(manager);
        user1 = new User(manager);
        user2 = new User(manager);
    }

    function setUpBurn() public {
        mint(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp + 1));
        manager.mint(address(this), 1e18);
        recycler.fill(1);
    }

    function testConstructor() public {
        assertEq(recycler.name(), "(Re)cycle Staked Tokemak");
        assertEq(recycler.symbol(), "(re)tTOKE");
        assertEq(recycler.decimals(), 18);
        assertEq(recycler.dust(), 0);
    }

    /**
     * `next`
     */

    function testNext() public {
        uint32 deadline = uint32(block.timestamp + 1);

        assertEq(recycler.cursor(), 0);
        recycler.next(deadline);
        assertEq(recycler.cursor(), 1);

        // epoch: 0
        assertEq(recycler.epochOf(0).deadline, 0);
        assertEq(recycler.epochOf(0).amount, 0);
        assertEq(recycler.epochOf(0).shares, 0);
        assertEq(recycler.epochOf(0).filled, true);
        // epoch: 1
        assertEq(recycler.epochOf(1).deadline, deadline);
        assertEq(recycler.epochOf(1).amount, 0);
        assertEq(recycler.epochOf(1).shares, 0);
        assertEq(recycler.epochOf(1).filled, false);

        // go to next cursor and check and its epoch
        recycler.next(deadline + 1);
        assertEq(recycler.cursor(), 2);
        assertEq(recycler.epochOf(2).deadline, deadline + 1);

        // check that there are two unfilled epochs in a row
        assertEq(recycler.epochOf(1).filled, false);
        assertEq(recycler.epochOf(2).filled, false);
    }

    /**
     * `mint`
     */

    function testMint() public {
        recycler.next(uint32(block.timestamp + 1));

        // mint as a user
        user0.mint(1e18);
        // balance still zero bc epoch not filled
        assertEq(recycler.balanceOf(address(user0)), 0);

        // mint as this
        mint(address(this), 3e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        // mint only 2 of 3
        manager.mint(address(this), 2e18);
        // 1 remaining
        assertEq(tokeVotePool.balanceOf(address(this)), 1e18);
        // balance still zero bc epoch not filled
        assertEq(recycler.balanceOf(address(this)), 0);

        // fill should make balance show up
        recycler.fill(1);
        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.balanceOf(address(this)), 2e18);
    }

    function testMintTickBufferIfFilled() public {
        recycler.next(uint32(block.timestamp + 1));

        user0.mint(1e18);
        warp(block.timestamp + 2);
        recycler.fill(1);

        assertEq(recycler.balanceOf(address(user0)), 1e18);
        assertEq(recycler.sharesOf(address(user0)), 0);
        assertEq(recycler.bufferAs(address(user0)).epoch, 1);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // simulate compounding on the recycler...
        mint(address(recycler), 1e18);

        // should revert if next epoch hasn't started
        startPrank(address(user0));
        mint(address(user0), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(user0), 1e18);
        stopPrank();

        // go next after compounding
        recycler.next(uint32(block.timestamp + 1));
        // mint again with user to see that it ticks
        user0.mint(1e18);

        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        recycler.fill(2);
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1);

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18 + 5e17);
        // the buffer does not get cleared, instead becomes for the epoch deposited
        assertEq(recycler.bufferAs(address(user0)).epoch, 3);
        assertEq(recycler.bufferAs(address(user0)).amount, 1);

        recycler.fill(3);
        assertEq(recycler.balanceOf(address(user0)), 3e18 + 1);
    }

    function testMintInsufficientTransferError() public {
    }

    function testMintEpochExpiredWhenFilledError() public {
    }

    function testMintEpochExpiredWhenDeadlinePassedError() public {
    }

    function testMintPastBufferExistsButNotFilledError() public {
    }

    /**
     * `burn`
     */

    function testBurn() public {
        setUpBurn();

        uint256 balance = recycler.balanceOf(address(this));
        recycler.burn(address(this), address(this), balance);
    }

    /**
     * `fill`
     */

    function testFill() public {
        mint(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp + 1));
        manager.mint(address(this), 1e18);

        assertEq(recycler.totalSupply(), 1e18);
        assertEq(recycler.totalShares(), 0);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(recycler.sharesOf(address(this)), 0);
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
        assertEq(recycler.epochOf(1).deadline, uint32(block.timestamp + 1));
        assertEq(recycler.epochOf(1).amount, 1e18);
        assertEq(recycler.epochOf(1).shares, 0);
        assertEq(recycler.epochOf(1).filled, false);

        recycler.fill(1);

        assertEq(recycler.totalSupply(), 1e18);
        assertEq(recycler.totalShares(), 1e18); // +
        assertEq(recycler.balanceOf(address(this)), 1e18); // + balance should be defined now bc filled
        assertEq(recycler.sharesOf(address(this)), 0); // + shares zero bc not tick:ed
        assertEq(recycler.bufferAs(address(this)).epoch, 1);
        assertEq(recycler.bufferAs(address(this)).amount, 1e18);
        assertEq(recycler.epochOf(1).deadline, uint32(block.timestamp + 1));
        assertEq(recycler.epochOf(1).amount, 1e18);
        assertEq(recycler.epochOf(1).shares, 1e18); // +
        assertEq(recycler.epochOf(1).filled, true); // +
    }

    /**
     * `tick`
     */

    function testTick() public {
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1e18);

        // fill and tick, and then check holdings
        recycler.fill(1);
        recycler.tick(address(user0));

        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
    }

    function testTickOnEmptyBuffer() public {
    }

    function testTickOnAlreadyTickedBuffer() public {
    }

    /**
     * Integration tests
     */

    function testMultipleUsers() public {
        recycler.next(uint32(block.timestamp + 1));
        
        user0.mint(1e18);
        user1.mint(3e18);
        user2.mint(6e18);

        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);
        assertEq(recycler.bufferAs(address(user1)).amount, 3e18);
        assertEq(recycler.bufferAs(address(user2)).amount, 6e18);

        warp(block.timestamp + 2);
        // block should revert bc deadline passed
        mint(address(this), 1e18);
        expectRevert(abi.encodeWithSignature("EpochExpired()"));
        manager.mint(address(this), 1e18);

        // no active coins, because not filled yet
        assertEq(recycler.balanceOf(address(user0)), 0);
        assertEq(recycler.balanceOf(address(user1)), 0);
        assertEq(recycler.balanceOf(address(user2)), 0);
        // fill
        recycler.fill(1);
        // simulate compounding by minting
        mint(address(recycler), 10e18);
        
        /// balance should double bc the epoch has been filled
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.balanceOf(address(user1)), 6e18);
        assertEq(recycler.balanceOf(address(user2)), 12e18);
        // shares should be zero bc accounts not ticked
        assertEq(recycler.sharesOf(address(user0)), 0);
        assertEq(recycler.sharesOf(address(user1)), 0);
        assertEq(recycler.sharesOf(address(user2)), 0);
        // buffer should be the same
        assertEq(recycler.bufferAs(address(user0)).epoch, 1);
        assertEq(recycler.bufferAs(address(user1)).epoch, 1);
        assertEq(recycler.bufferAs(address(user2)).epoch, 1);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);
        assertEq(recycler.bufferAs(address(user1)).amount, 3e18);
        assertEq(recycler.bufferAs(address(user2)).amount, 6e18);

        recycler.tick(address(user0));
        recycler.tick(address(user1));
        recycler.tick(address(user2));

        /// should be the same
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.balanceOf(address(user1)), 6e18);
        assertEq(recycler.balanceOf(address(user2)), 12e18);
        // should change bc we ticked
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.sharesOf(address(user1)), 3e18);
        assertEq(recycler.sharesOf(address(user2)), 6e18);
        // should be zero
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user1)).epoch, 0);
        assertEq(recycler.bufferAs(address(user2)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
        assertEq(recycler.bufferAs(address(user1)).amount, 0);
        assertEq(recycler.bufferAs(address(user2)).amount, 0);

        // go to next epoch: 2
        recycler.next(uint32(block.timestamp + 1));
        user0.mint(1e18);
        assertEq(recycler.balanceOf(address(user0)), 2e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // fill epoch: 2 and now we should have shares for user0
        recycler.fill(2);

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18);
        assertEq(recycler.bufferAs(address(user0)).epoch, 2);
        assertEq(recycler.bufferAs(address(user0)).amount, 1e18);

        // tick should reset buffer
        recycler.tick(address(user0));

        assertEq(recycler.balanceOf(address(user0)), 3e18);
        assertEq(recycler.sharesOf(address(user0)), 1e18 + 5e17);
        assertEq(recycler.bufferAs(address(user0)).epoch, 0);
        assertEq(recycler.bufferAs(address(user0)).amount, 0);
    }
}

contract User is Vm, Utilities {
    Manager public manager;

    constructor(Manager manager_) {
        manager = manager_;
    }

    function mint(uint256 amount) public {
        startPrank(address(this));
        mint(address(this), amount);
        tokeVotePool.approve(address(manager), type(uint256).max);
        manager.mint(address(this), amount);
        stopPrank();
    }
}

contract Manager {
    using SafeTransfer for address;

    struct CallbackData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    Recycler public recycler;
    address public token;

    constructor(Recycler recycler_, address token_) {
        recycler = recycler_;
        token = token_;
    }

    function mint(address to, uint256 amount) public {
        CallbackData memory data = CallbackData({
            token: token,
            payer: msg.sender,
            payee: address(recycler),
            amount: amount
        });

        recycler.mint(to, amount, abi.encode(data));
    }

    function mintCallback(bytes memory data) public {
        require(msg.sender == address(recycler), "Manager: Unauthorized");
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        decoded.token.safeTransferFrom(decoded.payer, decoded.payee, decoded.amount);
    }
}
