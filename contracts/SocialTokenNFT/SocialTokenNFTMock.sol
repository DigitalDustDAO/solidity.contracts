// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenNFT.sol";

abstract contract SocialTokenNFTMock is SocialTokenNFT {
    ISocialTokenManager internal manager;

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }
}
