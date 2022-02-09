// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenNFT.sol";

contract SocialTokenNFTMock is LongTailSocialNFT {
    constructor(
        address manager_
    ) LongTailSocialNFT(manager_) {}

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }
}
