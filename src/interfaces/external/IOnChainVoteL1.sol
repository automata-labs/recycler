// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/external/Tokemak.sol";

interface IOnChainVoteL1 {
    function vote(UserVotePayload memory data) external;
}
