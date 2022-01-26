// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ISocialTokenManager.sol";
import "./LongTailSocialToken.sol";
import "./SocialTokenNFT.sol";
import "./ISocialTokenNFT.sol";
import "./IDigitalDustDAO.sol";

contract SocialTokenManager is ISocialTokenManager {
    IDigitalDustDAO private dao;
    LongTailSocialToken private token;

    bytes4 iSocialTokenHash;
    bytes4 iSocialTokenNFTHash;
    uint64 daoId;

    constructor(address dao_, uint64 daoId_) {
        dao = IDigitalDustDAO(dao_);
        daoId = daoId_;
        token = LongTailSocialToken(address(0));

        iSocialTokenHash = type(ISocialTokenManager).interfaceId;
        iSocialTokenNFTHash = type(ISocialTokenNFT).interfaceId;
    }

    modifier hasToken {
        require(address(token) != address(0), "Must set token first");
        _;
    }

    modifier onlyOwner {
        require(dao.rightsOf(daoId, msg.sender) >= 500, "Not enough rights to update");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == iSocialTokenHash;
    }

    function setToken(address tokenAddr) public onlyOwner returns (address) {
        token = LongTailSocialToken(tokenAddr);
        return tokenAddr;
    }

    function setTokenManager(address contractAddr) public onlyOwner hasToken returns (address) {
        require(
            SocialTokenManager(contractAddr).supportsInterface(iSocialTokenHash),
            "Contract must support ISocialTokenManager"
        );

        token.setManager(contractAddr);
        return contractAddr;
    }

    function setNFT(address contractAddr) public onlyOwner hasToken returns (address) {
        require(
            SocialTokenNFT(contractAddr).supportsInterface(iSocialTokenNFTHash),
            "Contract must support ISocialTokenNFT"
        );

        token.setNFT(contractAddr);
        return contractAddr;
    }
}
