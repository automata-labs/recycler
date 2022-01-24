// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../Reactor.sol";
import "../Sequencer.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/OnChainVoteL1.sol";
import "./mocks/Rewards.sol";
import "./mocks/RewardsHash.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract User {}

contract SequencerTest is DSTest, Vm, Utilities {
    User public user0;
    User public user1;
    User public user2;

    Reactor public reactor;
    Sequencer public sequencer;

    function setUp() public {
        user0 = new User();
        user1 = new User();

        reactor = new Reactor(address(tokeVotePool), 0);
        sequencer = new Sequencer(
            address(reactor),
            address(0),
            address(tokeVotePool),
            address(rewards),
            address(rewardsHash),
            100
        );

        reactor.allow(address(sequencer));
    }

    function testSetUp() public {
        assertEq(rewardsHash.latestCycleIndex(), 170);
        (string memory latestClaimable, string memory latestCycle) = rewardsHash.cycleHashes(170);
        assertEq(latestClaimable, "QmPcAQx3Sg9rbsxvMh7bniMrW3tTy34kUeTqTmrZQfXXEV");
        assertEq(latestCycle, "QmQzL1jaDM9YtjZ7JDnSdKaXfSXEiHMtYnuF24eh93ceUi");
    }

    function testConstructor() public {
        assertEq(sequencer.name(), "Sequencing Automata TokemakTokePool");
        assertEq(sequencer.symbol(), "SAtTOKE");
        assertEq(sequencer.reactor(), address(reactor));
    }

    /**
     * `mint`
     */

    function testMint() public {
        tTOKEMint(address(this), 1e18);
        tokeVotePool.approve(address(sequencer), 1e18);
        sequencer.mint(address(this), 1e18);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 1e18);
        assertEq(tokeVotePool.balanceOf(address(sequencer)), 0);
        assertEq(reactor.buffer(), 1e18);

        assertEq(sequencer.balanceOf(address(this)), 1e18);
        assertEq(sequencer.cardinality(), 1);
        assertEq(sequencer.epoch().tokens, 1e18);
        assertEq(sequencer.epoch().shares, 0);
    }

    function testMintTwiceSameEpoch() public {
        tTOKEMint(address(this), 1e18);
        tokeVotePool.approve(address(sequencer), 1e18);
        sequencer.mint(address(this), 5e17);
        sequencer.mint(address(this), 5e17);
    }

    function testMintPollEpoch() public {
        prank(address(user0));
        tokeVotePool.approve(address(sequencer), type(uint256).max);
        prank(address(user1));
        tokeVotePool.approve(address(sequencer), type(uint256).max);

        // epoch: 0
        startPrank(address(user0));
        tTOKEMint(address(user0), 1e18);
        sequencer.mint(address(user0), 1e18);
        stopPrank();

        // epoch: 1
        rewardsHash.setCycleHashes(4, "b", "4");
        startPrank(address(user1));
        tTOKEMint(address(user1), 1e18);
        sequencer.mint(address(user1), 3e18);
        stopPrank();

        assertEq(sequencer.balanceOf(address(user0)), 1e18);
        assertEq(sequencer.balanceOf(address(user1)), 3e18);
        assertEq(sequencer.cardinality(), 2);
        assertEq(sequencer.epochAt(0).tokens, 1e18);
        assertEq(sequencer.epochAt(1).tokens, 3e18);
    }

    function testMintAmountRevert() public {
        expectRevert(abi.encodeWithSignature("Zero()"));
        sequencer.mint(address(this), 0);
    }

    function testMintDifferentEpochRevert() public {
        tokeVotePool.approve(address(sequencer), 1e18);

        tTOKEMint(address(this), 1e18);
        sequencer.mint(address(this), 5e17);

        rewardsHash.setCycleHashes(4, "b", "4");
        expectRevert(abi.encodeWithSignature("NonEmptyBalance()"));
        sequencer.mint(address(this), 5e17);
    }

    /**
     * `fill`
     */

    function testFill() public {
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(this), 1e18);
        sequencer.mint(address(this), 1e18);
        sequencer.fill(0);
        assertEq(reactor.totalSupply(), 1e18);
        assertEq(reactor.balanceOf(address(sequencer)), 1e18);
        assertEq(reactor.balanceOf(address(this)), 0);
        assertEq(sequencer.epoch().hash, keccak256(abi.encodePacked("a")));
        assertEq(sequencer.epoch().cycle, 3);
        assertEq(sequencer.epoch().tokens, 1e18);
        assertEq(sequencer.epoch().shares, 1e18);
        assert(sequencer.epoch().filled == true);
    }

    function testFillNonZeroIndexEpochAndReducingShares() public {
        startPrank(address(user0));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user0), 1e18);
        sequencer.mint(address(user0), 1e18);
        stopPrank();

        rewardsHash.setCycleHashes(4, "b", "4");

        startPrank(address(user1));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user1), 1e18);
        sequencer.mint(address(user1), 1e18);
        stopPrank();

        sequencer.fill(0);
        tTOKEMint(address(reactor), 1e18); // acts as a claim
        sequencer.fill(1);

        assertEq(sequencer.epochAt(0).tokens, 1e18);
        assertEq(sequencer.epochAt(0).shares, 1e18);
        assertEq(sequencer.epochAt(1).tokens, 1e18);
        assertEq(sequencer.epochAt(1).shares, 5e17);
    }

    function testFillDiscontinuousEpochFillRevert() public {
        startPrank(address(user0));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user0), 1e18);
        sequencer.mint(address(user0), 1e18);
        stopPrank();

        rewardsHash.setCycleHashes(4, "b", "4");

        startPrank(address(user1));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user1), 1e18);
        sequencer.mint(address(user1), 1e18);
        stopPrank();

        expectRevert(abi.encodeWithSignature("BadEpoch()"));
        sequencer.fill(1);
    }

    /**
     * `join`
     */

    function testJoin() public {
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(this), 1e18);
        sequencer.mint(address(this), 1e18);
        sequencer.fill(0);

        assertEq(reactor.balanceOf(address(sequencer)), 1e18);
        sequencer.join(address(this));
        assertEq(reactor.balanceOf(address(this)), 1e18);
    }

    function testJoinWithTwoUsers() public {
        startPrank(address(user0));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user0), 1e18);
        sequencer.mint(address(user0), 1e18);
        stopPrank();

        sequencer.fill(0);

        prank(address(user0));
        sequencer.join(address(user0));
        assertEq(sequencer.balanceOf(address(user0)), 0);
        assertEq(reactor.balanceOf(address(user0)), 1e18);

        tTOKEMint(address(reactor), 6e18);
        rewardsHash.setCycleHashes(4, "b", "4");

        startPrank(address(user1));
        tokeVotePool.approve(address(sequencer), 3e18);
        tTOKEMint(address(user1), 3e18);
        sequencer.mint(address(user1), 3e18);
        stopPrank();

        startPrank(address(user2));
        tokeVotePool.approve(address(sequencer), 2e18);
        tTOKEMint(address(user2), 2e18);
        sequencer.mint(address(user2), 2e18);
        stopPrank();

        sequencer.fill(1);

        prank(address(user1));
        sequencer.join(address(user1));
        assertEq(reactor.balanceOf(address(user1)), 428571428571428571);

        prank(address(user2));
        sequencer.join(address(user2));
        assertEq(reactor.balanceOf(address(user2)), 285714285714285714);

        assertEq(reactor.balanceOf(address(sequencer)), 0);
    }

    function testJoinWithTwoUsersRoundNumber() public {
        startPrank(address(user0));
        tokeVotePool.approve(address(sequencer), 1e18);
        tTOKEMint(address(user0), 1e18);
        sequencer.mint(address(user0), 1e18);
        stopPrank();

        sequencer.fill(0);

        prank(address(user0));
        sequencer.join(address(user0));
        assertEq(sequencer.balanceOf(address(user0)), 0);
        assertEq(reactor.balanceOf(address(user0)), 1e18);

        tTOKEMint(address(reactor), 1e18);
        rewardsHash.setCycleHashes(4, "b", "4");

        startPrank(address(user1));
        tokeVotePool.approve(address(sequencer), 3e18);
        tTOKEMint(address(user1), 3e18);
        sequencer.mint(address(user1), 3e18);
        stopPrank();

        startPrank(address(user2));
        tokeVotePool.approve(address(sequencer), 2e18);
        tTOKEMint(address(user2), 2e18);
        sequencer.mint(address(user2), 2e18);
        stopPrank();

        sequencer.fill(1);

        prank(address(user1));
        sequencer.join(address(user1));
        assertEq(reactor.balanceOf(address(user1)), 1e18 + 5e17);

        prank(address(user2));
        sequencer.join(address(user2));
        assertEq(reactor.balanceOf(address(user2)), 1e18);

        assertEq(reactor.balanceOf(address(sequencer)), 0);
    }
}
