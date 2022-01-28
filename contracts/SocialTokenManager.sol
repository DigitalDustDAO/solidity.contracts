// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ISocialTokenManager.sol";
import "./LongTailSocialToken.sol";
import "./SocialTokenNFT.sol";
import "./ISocialTokenNFT.sol";
import "./IDigitalDustDAO.sol";

contract SocialTokenManager is ISocialTokenManager {
    IDigitalDustDAO public dao;
    LongTailSocialToken public token;

    bytes4 iSocialTokenHash;
    bytes4 iSocialTokenNFTHash;
    uint256 daoId;

    constructor(address dao_, uint256 daoId_) {
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

    function authorize(address source, address target, uint8 level) external view returns(bool) {
        if (level <= 1) { // user
            return source == target 
                ? dao.rightsOf(daoId, source) >= 100 && dao.penaltyOf(daoId, source) == 0
                : dao.rightsOf(daoId, source) >= 100 && dao.rightsOf(daoId, target) >= 100 && dao.penaltyOf(daoId, source) == 0 && dao.penaltyOf(daoId, target) == 0;
        }
        if (level <= 2) { // community
            return true;
        }
        else if (level == 3) { // council
            return source == target 
                ? dao.rightsOf(daoId, source) >= 400 && dao.penaltyOf(daoId, source) < 100
                : dao.rightsOf(daoId, source) >= 400 && dao.rightsOf(daoId, target) >= 400 && dao.penaltyOf(daoId, source) < 100 && dao.penaltyOf(daoId, target) < 100;
        }
        else { // invalid input, deny
            return false;
        }
    }

        function adjustInterest() external {
            // not implemented
        }

}
