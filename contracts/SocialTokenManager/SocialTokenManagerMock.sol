// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./Bootstrapper.sol";

contract SocialTokenManagerMock is Bootstrapper {
    constructor(
        address dao_,
<<<<<<< HEAD
        uint256 daoId_,
        address tokenAddr_,
        address nftAddr_
    ) SocialTokenManager(dao_, daoId_, tokenAddr_, nftAddr_) {}
=======
        uint256 daoId_
    ) Bootstrapper(dao_, daoId_) {}
>>>>>>> 2c26492bdba5a1fc0820c6e19fb5a42e08d66030

    function callTokenSetManager(address newManager, bool startInterestAdjustment) public {
        getTokenContract().setManager(newManager, startInterestAdjustment);
    }

    function callNftSetManager(address newManager) public {
        getNftContract().setManager(newManager);
    }
}
