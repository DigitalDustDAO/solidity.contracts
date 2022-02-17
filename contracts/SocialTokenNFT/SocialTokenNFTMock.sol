// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./LongTailSocialNFT.sol";

contract SocialTokenNFTMock is LongTailSocialNFT {
    constructor(
        address manager_
    ) LongTailSocialNFT(manager_) {}

    function getInterfaceId() external pure returns(bytes4) {
        return type(ISocialTokenNFT).interfaceId;
    }

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }

    function assertSupportsInterface(bytes4 interfaceId) public view virtual {
        require(supportsInterface(interfaceId));
    }
}
