// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./BootstrapManager.sol";

contract BootstrapManagerMock is BootstrapManager {
    constructor(
        address dao_,
        uint256 daoId_
    ) BootstrapManager(dao_, daoId_) {}

    function getInterfaceId() public pure returns (bytes4) {
        return type(ISocialTokenManager).interfaceId;
    }

    // contracts became private, can't use them
    // function callTokenSetManager(address newManager, bool startInterestAdjustment) public {
    //     tokenContract.setManager(newManager, startInterestAdjustment);
    // }

    // function callNftSetManager(address newManager) public {
    //     nftContract.setManager(newManager);
    // }
}
