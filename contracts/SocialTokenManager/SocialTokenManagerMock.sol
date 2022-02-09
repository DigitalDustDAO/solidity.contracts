// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenManager.sol";

contract SocialTokenManagerMock is SocialTokenManager {
    constructor(
        address dao_,
        uint256 daoId_
    ) SocialTokenManager(dao_, daoId_) {}

    function callTokenSetManager(address newManager, bool startInterestAdjustment) public {
        tokenContract.setManager(newManager, startInterestAdjustment);
    }

    function callNftSetManager(address newManager) public {
        nftContract.setManager(newManager);
    }
}
