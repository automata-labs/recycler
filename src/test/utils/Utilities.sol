// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "yield-utils-v2/token/IERC20.sol";

import "../../interfaces/external/IManager.sol";
import "../../interfaces/external/IOnChainVoteL1.sol";
import "../../interfaces/external/IRewards.sol";
import "../../interfaces/external/IRewardsHash.sol";
import "../../interfaces/external/IStaking.sol";
import "../../interfaces/external/ITokeVotePool.sol";
import "../../interfaces/v0/IRecyclerVaultV0.sol";
import "../utils/Vm.sol";

contract Utilities is DSTest, Vm {
    struct KeyPair {
        address publicKey;
        uint256 privateKey;
    }

    KeyPair public keyPair = KeyPair({
        publicKey: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        privateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    });

    IManager public manager = IManager(0xA86e412109f77c45a3BC1c5870b880492Fb86A14);
    IOnChainVoteL1 public onchainvote = IOnChainVoteL1(0x43094eD6D6d214e43C31C38dA91231D2296Ca511);
    IRecyclerVaultV0 public recyclerV0 = IRecyclerVaultV0(0x707059006C9936d13064F15FA963a528eC98A055);
    IRewards public rewards = IRewards(0x79dD22579112d8a5F7347c5ED7E609e60da713C5);
    IRewardsHash public rewardsHash = IRewardsHash(0x5ec3EC6A8aC774c7d53665ebc5DDf89145d02fB6);
    IStaking public staking = IStaking(0x96F98Ed74639689C3A11daf38ef86E59F43417D3);
    IERC20 public toke = IERC20(0x2e9d63788249371f1DFC918a52f8d799F4a38C94);
    ITokeVotePool public tokeVotePool = ITokeVotePool(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930);

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

    function realloc_buffer(address recycler, uint256 amount) public {
        store(recycler, bytes32(uint256(10)), bytes32(uint256(amount)));
    }

    function realloc_current_cycle_index(uint256 currentCycleIndex) public {
        store(address(manager), bytes32(uint256(102)), bytes32(uint256(currentCycleIndex)));
    }

    function realloc_epoch(
        address recycler,
        uint256 epoch,
        uint32 deadline,
        uint104 amount,
        uint104 shares,
        bool filled
    ) public {
        uint256 word;

        word = (filled) ? (1 << 240) : 0;
        word += shares << 136;
        word += amount << 32;
        word += deadline << 0;

        store(recycler, keccak256(abi.encode(epoch, 13)), bytes32(uint256(word)));
    }

    function realloc_shares(address recycler, uint256 totalCoins, uint256 totalShares) public {
        realloc_ttoke(recycler, totalCoins);
        store(recycler, bytes32(uint256(9)), bytes32(uint256(totalShares)));
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
    ) public returns (IRewards.Recipient memory recipient, uint8 v, bytes32 r, bytes32 s) {
        recipient = IRewards.Recipient({
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
