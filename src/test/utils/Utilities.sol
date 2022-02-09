// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../../interfaces/external/IOnChainVoteL1.sol";
import "../mocks/Rewards.sol";
import "../mocks/RewardsHash.sol";
import "../mocks/TokeVotePool.sol";
import "../mocks/TokeVotePool.sol";
import "../utils/Vm.sol";

contract Utilities is DSTest, Vm {
    IOnChainVoteL1 public onchainvote = IOnChainVoteL1(0x43094eD6D6d214e43C31C38dA91231D2296Ca511);
    Rewards public rewards = Rewards(0x79dD22579112d8a5F7347c5ED7E609e60da713C5);
    RewardsHash public rewardsHash = RewardsHash(0x5ec3EC6A8aC774c7d53665ebc5DDf89145d02fB6);
    IERC20 public toke = IERC20(0x2e9d63788249371f1DFC918a52f8d799F4a38C94);
    TokeVotePool public tokeVotePool = TokeVotePool(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930);

    function realloc_toke(address account, uint256 amount) public {
        uint256 balance = toke.balanceOf(account);
        store(address(toke), keccak256(abi.encode(account, 0)), bytes32(balance + amount));
    }

    function realloc_ttoke(address account, uint256 amount) public {
        uint256 balance = tokeVotePool.balanceOf(account);
        store(address(tokeVotePool), keccak256(abi.encode(account, 51)), bytes32(balance + amount));
    }

    function realloc_reward_signer(address signer) public {
        store(address(rewards), bytes32(uint256(2)), bytes32(uint256(uint160(signer))));
    }

    function assertEq(bool x, bool y) internal {
        if (x != y) {
            emit log("Error: Assertion Failed");
            fail();
        }
    }

    function buildRecipient(
        uint256 chainId,
        uint256 cycle,
        address wallet,
        uint256 amount,
        uint256 privateKey
    ) public returns (Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) {
        recipient = Recipient({
            chainId: chainId,
            cycle: cycle,
            wallet: wallet,
            amount: amount
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes("TOKE Distribution")),
                        keccak256(bytes("1")),
                        uint256(recipient.chainId),
                        address(rewards)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)"),
                        recipient.chainId,
                        recipient.cycle,
                        recipient.wallet,
                        recipient.amount
                    )
                )
            )
        );

        (v, r, s) = sign(privateKey, digest);
    }
}
