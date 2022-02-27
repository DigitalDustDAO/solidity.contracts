// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./LongTailSocialNFT.sol";
import "./ISocialTokenNFT.sol";

contract SocialTokenNFTMock is LongTailSocialNFT {
    address private _sender;

    constructor(
        address manager_
    ) LongTailSocialNFT(manager_) {}

    function setMsgSender(address sender_) public {
        _sender = sender_;
    }

    function _msgSender() internal view override returns (address) {
        return _sender == address(0) ? msg.sender : _sender;
    }

    function getInterfaceId() external pure returns (bytes4) {
        return type(ISocialTokenNFT).interfaceId;
    }

    function getForgeValues() external view returns (uint256, uint256, uint256, int256) {
        return (
            maximumElementMint,
            elementMintCost,
            forgeCost,
            tokenRewardPerBounty
        );
    }

    function getBaseURI() external view returns (string memory) {
        return baseTokenURI;
    }

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }

    function assertSupportsInterface(bytes4 interfaceId) public view virtual {
        require(supportsInterface(interfaceId));
    }
}
