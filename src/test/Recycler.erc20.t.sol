// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../Recycler.sol";
import "../RecyclerManager.sol";
import "./utils/Utilities.sol";
import "./utils/Vm.sol";

contract User {}

contract RecyclerERC20 is DSTest, Vm, Utilities {
    Recycler public recycler;
    RecyclerManager public manager;

    User public user0;
    User public user1;

    function setUp() public {
        recycler = new Recycler(
            address(toke),
            address(tokeVotePool),
            address(onchainvote),
            address(rewards),
            0
        );
        manager = new RecyclerManager(address(tokeVotePool), IRecycler(recycler));

        user0 = new User();
        user1 = new User();
    }

    function testConstructor() public {
        assertEq(recycler.underlying(), address(toke));
        assertEq(recycler.derivative(), address(tokeVotePool));
        assertEq(recycler.onchainvote(), address(onchainvote));
        assertEq(recycler.rewards(), address(rewards));
        assertEq(recycler.dust(), 0);
        assertEq(recycler.capacity(), type(uint256).max);
        assertEq(recycler.epochAs(0).deadline, 0);
        assertEq(recycler.epochAs(0).amount, 0);
        assertEq(recycler.epochAs(0).shares, 0);
        assertEq(recycler.epochAs(0).filled, true);
    }

    function testMetadata() public {
        assertEq(recycler.name(), "(Re)cycler Staked Tokemak");
        assertEq(recycler.symbol(), "(re)tTOKE");
        assertEq(recycler.decimals(), 18);
        assertEq(recycler.version(), "1");
    }

    /**
     * `transfer`
     */

    function testTransfer() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 1e18);
        recycler.fill(1);

        recycler.transfer(address(user0), 1e18);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(recycler.balanceOf(address(user0)), 1e18);
    }

    // should still transfer when the amount of coins per share is more than 1
    function testTransferNotEqualRatio() public {
        realloc_shares(address(recycler), 6e18, 4e18);
        realloc_ttoke(address(this), 5e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 5e18);
        recycler.fill(1);

        recycler.poke(address(this));
        assertEq(recycler.sharesOf(address(this)), 3333333333333333333);
        assertEq(recycler.balanceOf(address(this)), 4999999999999999999);

        recycler.transfer(address(user0), 4999999999999999999);
        // dust left in sender's wallet
        assertEq(recycler.sharesOf(address(this)), 1);
        assertEq(recycler.balanceOf(address(this)), 1);
        // possible loss of 1 when transferring (incl. all coin -> shares conversion).
        // there can always be loss of precision if you send an amount that's in-between two units
        // of shares (during conversion).
        assertEq(recycler.sharesOf(address(user0)), 3333333333333333332);
        assertEq(recycler.balanceOf(address(user0)), 4999999999999999998);

        assertEq(recycler.totalSupply(), 11e18);
    }

    function testTransfer(uint104 amount) public {
        realloc_ttoke(address(this), amount);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), amount);
        recycler.fill(1);

        assertEq(recycler.transfer(address(user0), amount), true);
        assertEq(recycler.totalSupply(), amount);
        assertEq(recycler.balanceOf(address(this)), 0);
        assertEq(recycler.balanceOf(address(user0)), amount);
    }

    function testTransferInsufficientBalanceError() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 1e18);
        recycler.fill(1);

        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.transfer(address(user0), 1e18 + 1);
    }

    // should revert insufficient balance when one share is more than one coin
    function testTransferNotEqualRatioInsufficientBalanceError() public {
        realloc_shares(address(recycler), 6e18, 4e18);
        realloc_ttoke(address(this), 5e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 5e18);
        recycler.fill(1);

        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.transfer(address(user0), 4999999999999999999 + 100);
    }

    /**
     * `transferFrom`
     */

    function testTransferFrom() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 1e18);
        recycler.fill(1);

        recycler.approve(address(user0), 1e18);
        startPrank(address(user0));
        recycler.transferFrom(address(this), address(user1), 1e18);
        stopPrank();
        assertEq(recycler.balanceOf(address(user1)), 1e18);
    }

    function testTransferFromInsufficientAllowanceError() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 1e18);
        recycler.fill(1);

        recycler.approve(address(user0), 1e18 - 1);
        startPrank(address(user0));
        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.transferFrom(address(this), address(user0), 1e18);
        stopPrank();
    }

    function testTranasferFromInsufficientBalanceError() public {
        realloc_ttoke(address(this), 1e18);
        tokeVotePool.approve(address(manager), type(uint256).max);
        recycler.next(uint32(block.timestamp) + 1);
        manager.mint(address(this), 1e18);
        recycler.fill(1);

        recycler.approve(address(user0), type(uint256).max);
        expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        recycler.transferFrom(address(this), address(user0), 1e18 + 1);
    }

    /**
     * `approve`
     */

    function testApprove() public {
        assertEq(recycler.approve(address(user0), 1e18), true);
        assertEq(recycler.allowance(address(this), address(user0)), 1e18);
    }

    function testApprove(address to, uint256 amount) public {
        assertEq(recycler.approve(to, amount), true);
        assertEq(recycler.allowance(address(this), to), amount);
    }

    /**
     * `permit`
     */

    function testPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = sign(
            keyPair.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    recycler.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            recycler.PERMIT_TYPEHASH(),
                            keyPair.publicKey,
                            address(user0),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp, v, r, s);
        assertEq(recycler.allowance(keyPair.publicKey, address(user0)), 1e18);
        assertEq(recycler.nonces(keyPair.publicKey), 1);
    }

    function testPermitInvalidNonce() public {
        (uint8 v, bytes32 r, bytes32 s) = sign(
            keyPair.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    recycler.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            recycler.PERMIT_TYPEHASH(),
                            keyPair.publicKey,
                            address(user0),
                            1e18,
                            1,
                            block.timestamp
                        )
                    )
                )
            )
        );

        expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp, v, r, s);
    }

    function testPermitInvalidDeadlineError() public {
        (uint8 v, bytes32 r, bytes32 s) = sign(
            keyPair.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    recycler.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            recycler.PERMIT_TYPEHASH(),
                            keyPair.publicKey,
                            address(user0),
                            1e18,
                            1,
                            block.timestamp - 1
                        )
                    )
                )
            )
        );

        expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp - 1, v, r, s);
        expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp + 1, v, r, s);
    }

    function testPermitInvalidSignatureError() public {
        (uint8 v, bytes32 r, bytes32 s) = sign(
            keyPair.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    recycler.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            recycler.PERMIT_TYPEHASH(),
                            keyPair.publicKey,
                            address(user0),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp, v, r, s);
        expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        recycler.permit(keyPair.publicKey, address(user0), 1e18, block.timestamp, v, r, s);
    }
}
