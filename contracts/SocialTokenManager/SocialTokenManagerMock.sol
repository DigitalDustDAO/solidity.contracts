// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./Bootstrapper.sol";

contract SocialTokenManagerMock is Bootstrapper {
    constructor(
        address dao_,
        uint256 daoId_
    ) Bootstrapper(dao_, daoId_) {}

    function callTokenSetManager(address newManager, bool startInterestAdjustment) public {
        getTokenContract().setManager(newManager, startInterestAdjustment);
    }

    function callNftSetManager(address newManager) public {
        getNftContract().setManager(newManager);
    }
}
