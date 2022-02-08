// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SocialTokenNFT.sol";

contract SocialTokenNFTMock is SocialTokenNFT {
    constructor(
        address manager_,
        string memory name_,
        string memory symbol_
    ) SocialTokenNFT(manager_, name_, symbol_) {}

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }
}
