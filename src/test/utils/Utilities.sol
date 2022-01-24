// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../mocks/Rewards.sol";
import "../mocks/RewardsHash.sol";
import "../mocks/TokeVotePool.sol";
import "../utils/Vm.sol";

contract Utilities is Vm {
    Rewards public rewards = Rewards(0x79dD22579112d8a5F7347c5ED7E609e60da713C5);
    RewardsHash public rewardsHash = RewardsHash(0x5ec3EC6A8aC774c7d53665ebc5DDf89145d02fB6);
    TokeVotePool public tokeVotePool = TokeVotePool(0xa760e26aA76747020171fCF8BdA108dFdE8Eb930);

    function tTOKEMint(address account, uint256 amount) public {
        store(address(tokeVotePool), keccak256(abi.encode(account, 51)), bytes32(amount));
    }
}
