// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/external/IRewards.sol";

struct Recipient {
    uint256 chainId;
    uint256 cycle;
    address wallet;
    uint256 amount;
}

struct UserVotePayload {
    address account;
    bytes32 voteSessionKey;
    uint256 nonce;
    uint256 chainId;
    uint256 totalVotes;
    UserVoteAllocationItem[] allocations;
}

struct UserVoteAllocationItem {
    bytes32 reactorKey; //asset-default, in actual deployment could be asset-exchange
    uint256 amount; //18 Decimals
}
