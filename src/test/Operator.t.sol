// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../interfaces/external/IRewards.sol";
import "../Reactor.sol";
import "../Operator.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/OnChainVoteL1.sol";
import "./mocks/Rewards.sol";
import "./mocks/RewardsHash.sol";
import "./mocks/TokeVotePool.sol";
import "./utils/Vm.sol";

library KeyPair {
    address public constant publicKey = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract OperatorTest is DSTest, Vm {
    ERC20Mock public erc20;
    OnChainVoteL1 public onchainvote;
    Rewards public rewards;
    RewardsHash public rewardsHash;
    TokeVotePool public tokeVotePool;
    
    Reactor public reactor;
    Operator public operator;

    function setUp() public {
        erc20 = new ERC20Mock("Tokemak", "TOKE", 18);
        tokeVotePool = new TokeVotePool(ERC20(erc20), "TokemakTokePool", "TOKE", 18);
        onchainvote = new OnChainVoteL1();
        rewards = new Rewards(IERC20(erc20), KeyPair.publicKey);
        rewardsHash = new RewardsHash();

        reactor = new Reactor(address(tokeVotePool), 0);
        operator = new Operator(
            address(reactor),
            address(erc20),
            address(tokeVotePool),
            address(onchainvote),
            address(rewards),
            address(rewardsHash)
        );

        erc20.mint(address(rewards), 100000 * 1e18);
        reactor.allow(address(operator));

        rewardsHash.setCycleHashes(0, "a", "0");
        rewardsHash.setCycleHashes(1, "a", "1");
        rewardsHash.setCycleHashes(2, "a", "2");
        rewardsHash.setCycleHashes(3, "a", "3");
    }

    function testConstructor() public {
        assertEq(operator.reactor(), address(reactor));
    }

    /**
     * `prepare`
     */

    function testPrepare() public {
        assertEq(erc20.allowance(address(reactor), address(tokeVotePool)), 0);
        operator.prepare(type(uint256).max);
        assertEq(erc20.allowance(address(reactor), address(tokeVotePool)), type(uint256).max);
    }

    function testPrepareNoAuthRevert() public {
        reactor.deny(address(operator));
        expectRevert("Denied");
        operator.prepare(0);
    }

    /**
     * `claim`
     */

    function testClaim() public {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes("TOKE Distribution")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(rewards)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)"),
                        uint256(1),
                        uint256(0),
                        address(reactor),
                        uint256(1e18)
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = sign(KeyPair.privateKey, digest);
        Recipient memory recipient = Recipient({
            chainId: 1,
            cycle: 0,
            wallet: address(reactor),
            amount: 1e18
        });

        assertEq(erc20.balanceOf(address(reactor)), 0);
        operator.claim(recipient, v, r, s);
        assertEq(erc20.balanceOf(address(reactor)), 1e18);
    }

    /**
     * `deposit`
     */

    function testDeposit() public {
        erc20.mint(address(reactor), 1e18);
        operator.prepare(1e18);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 0);
        operator.deposit(1e18);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 1e18);
    }

    /**
     * `compound`
     */

    function testCompound() public {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes("TOKE Distribution")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(rewards)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)"),
                        uint256(1),
                        uint256(0),
                        address(reactor),
                        uint256(1e18)
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = sign(KeyPair.privateKey, digest);
        Recipient memory recipient = Recipient({
            chainId: 1,
            cycle: 0,
            wallet: address(reactor),
            amount: 1e18
        });
        assertEq(tokeVotePool.balanceOf(address(reactor)), 0);
        operator.prepare(type(uint256).max);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 1e18);

        // claim and deposit again, to get `getClaimableAmount`
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes("TOKE Distribution")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(rewards)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)"),
                        uint256(1),
                        uint256(0),
                        address(reactor),
                        uint256(3e18)
                    )
                )
            )
        );
        (v, r, s) = sign(KeyPair.privateKey, digest);
        recipient = Recipient({
            chainId: 1,
            cycle: 0,
            wallet: address(reactor),
            amount: 3e18
        });
        assertEq(tokeVotePool.balanceOf(address(reactor)), 1e18);
        operator.prepare(type(uint256).max);
        operator.compound(recipient, v, r, s);
        assertEq(tokeVotePool.balanceOf(address(reactor)), 3e18);
    }

    /**
     * `vote`
     */

    function testVote() public {
        UserVoteAllocationItem[] memory allocations = new UserVoteAllocationItem[](3);
        allocations[0] = UserVoteAllocationItem({ reactorKey: bytes32("tcr-default"), amount: 1e18 });
        allocations[1] = UserVoteAllocationItem({ reactorKey: bytes32("fxs-default"), amount: 1e18 });
        allocations[2] = UserVoteAllocationItem({ reactorKey: bytes32("eth-default"), amount: 1e18 });
        UserVotePayload memory data = UserVotePayload({
            account: address(reactor),
            voteSessionKey: 0x00000000000000000000000000000000000000000000000000000000000000a6,
            nonce: 0,
            chainId: block.chainid,
            totalVotes: 6e18,
            allocations: allocations
        });

        operator.vote(data);
    }
}
