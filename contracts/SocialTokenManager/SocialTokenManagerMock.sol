// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenManager.sol";

contract SocialTokenManagerMock is SocialTokenManager {
        constructor(
        address dao_,
        uint256 daoId_
    ) SocialTokenManager(dao_, daoId_) {}
}
