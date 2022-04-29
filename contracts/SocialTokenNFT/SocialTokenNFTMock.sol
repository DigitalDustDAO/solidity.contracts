// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./LongTailSocialNFT.sol";
import "./ISocialTokenNFT.sol";

contract SocialTokenNFTMock is LongTailSocialNFT {
    address private _sender;
    bytes32 private constant uriUnlockString = 0x180d9267f8f17c313c9b13ca786ddb570e4b8bf845ccaf6eeb3c62b590a5ac9e;
                                // ^ the result of attempting to sign "Unlock rule 34 functionality" in metamask.

    constructor(
        address manager_
    ) LongTailSocialNFT(manager_, uriUnlockString) {}

    function setMsgSender(address sender_) public {
        _sender = sender_;
    }

    function _msgSender() internal view override returns (address) {
        return _sender == address(0) ? msg.sender : _sender;
    }

    function getInterfaceId() external pure returns (bytes4) {
        return type(ISocialTokenNFT).interfaceId;
    }

    function getForgeValues() external view returns (uint256, uint256) {
        return (
            uint256(elementMintCost),
            forgeCost
        );
    }

    // function getBaseURI() external view returns (string memory) {
    //     return baseTokenURI;
    // }

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }

    function assertSupportsInterface(bytes4 interfaceId) public view virtual {
        require(supportsInterface(interfaceId));
    }
}
