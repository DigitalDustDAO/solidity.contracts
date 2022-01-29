// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ISocialTokenManager.sol";
import "./ISocialToken.sol";
//import "./SocialTokenNFT.sol";
import "./ISocialTokenNFT.sol";
import "./IDigitalDustDAO.sol";

contract SocialTokenManager is ISocialTokenManager {
    IDigitalDustDAO public dao;
    ISocialToken public token;
    bytes4 iSocialTokenHash;
    ISocialTokenNFT public nft;
    bytes4 iSocialTokenNFTHash;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";

    constructor(address dao_, uint256 daoId_) {
        dao = IDigitalDustDAO(dao_);
        daoId = daoId_;
        token = ISocialToken(address(0));

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
        token = ISocialToken(tokenAddr);
        return tokenAddr;
    }

    function setTokenManager(address contractAddr) public onlyOwner hasToken returns (address) {
        // require(
        //     SocialTokenManager(contractAddr).supportsInterface(iSocialTokenHash),
        //     "Contract must support ISocialTokenManager"
        // );

        token.setManager(contractAddr, false);
        return contractAddr;
    }

    function setNFT(address contractAddr) public onlyOwner hasToken returns (address) {
        // require(
        //     SocialTokenNFT(contractAddr).supportsInterface(iSocialTokenNFTHash),
        //     "Contract must support ISocialTokenNFT"
        // );

        token.setNFT(contractAddr);
        return contractAddr;
    }

    function authorize(address source, address target, Sensitivity level) external {
        if (level == Sensitivity.Basic) {
            require(dao.rightsOf(daoId, source) >= 100 && dao.rightsOf(daoId, target) >= 100 && dao.penaltyOf(daoId, source) == 0 && dao.penaltyOf(daoId, target) == 0, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(dao.rightsOf(daoId, source) >= 400 && dao.rightsOf(daoId, target) >= 400 && dao.penaltyOf(daoId, source) < 100 && dao.penaltyOf(daoId, target) < 100, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(dao.rightsOf(daoId, source) >= 400 && dao.rightsOf(daoId, target) >= 400, UNAUTHORIZED);
        }
        else { // invalid input, deny
            require(false, UNAUTHORIZED);
        }
    }

    function authorize(address source, Sensitivity level) external {
        if (level == Sensitivity.Basic) {
            require(dao.rightsOf(daoId, source) >= 100 && dao.penaltyOf(daoId, source) == 0, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(dao.rightsOf(daoId, source) >= 400 && dao.penaltyOf(daoId, source) < 100, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(dao.rightsOf(daoId, source) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.NFTContract) {
            require(source == address(nft), UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(source == address(token), UNAUTHORIZED);
        }
        else { // invalid input, deny
            require(false, UNAUTHORIZED);
        }
    }

    function adjustInterest() external {
        // not implemented
    }

}
