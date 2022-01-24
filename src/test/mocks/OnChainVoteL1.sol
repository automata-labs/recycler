// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/external/Tokemak.sol";

contract OnChainVoteL1 {
    function vote(UserVotePayload memory userVotePayload) external {
        require(msg.sender == userVotePayload.account, "INVALID_ACCOUNT");
        bytes32 eventSig = "Vote";
    }
}
