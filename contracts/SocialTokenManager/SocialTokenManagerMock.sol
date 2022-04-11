// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenManager.sol";

contract SocialTokenManagerMock is SocialTokenManager {
    constructor(
        address dao_,
        uint256 daoId_,
        address tokenAddr_,
        address auxAddr_,
        address nftAddr_
    ) SocialTokenManager(dao_, daoId_, tokenAddr_, auxAddr_, nftAddr_) {}

    function callTokenSetManager(address newManager, bool startInterestAdjustment) public {
        this.getTokenContract().setManager(newManager, startInterestAdjustment);
    }

    function callNftSetManager(address newManager) public {
        this.getNftContract().setManager(newManager);
    }
}
