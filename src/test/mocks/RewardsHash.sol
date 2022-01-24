// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import "../../interfaces/external/IRewardsHash.sol";

contract RewardsHash is IRewardsHash, Ownable {
    using SafeMath for uint256;

    mapping(uint256 => CycleHashTuple) public override cycleHashes;
    uint256 public latestCycleIndex;
    
    constructor() { 
        latestCycleIndex = 0;
    }

    function setCycleHashes(uint256 index, string calldata latestClaimableIpfsHash, string calldata cycleIpfsHash) external override onlyOwner {
        require(bytes(latestClaimableIpfsHash).length > 0, "Invalid latestClaimableIpfsHash");
        require(bytes(cycleIpfsHash).length > 0, "Invalid cycleIpfsHash");

        cycleHashes[index] = CycleHashTuple(latestClaimableIpfsHash, cycleIpfsHash);

        if (index >= latestCycleIndex) {
            latestCycleIndex = index;
        }

        emit CycleHashAdded(index, latestClaimableIpfsHash, cycleIpfsHash);
    }
}
