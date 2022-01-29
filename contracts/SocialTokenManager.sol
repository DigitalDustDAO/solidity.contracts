// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./ISocialTokenManager.sol";
import "./ISocialToken.sol";
//import "./SocialTokenNFT.sol";
import "./ISocialTokenNFT.sol";
import "./IDigitalDustDAO.sol";

contract SocialTokenManager is ISocialTokenManager, Context, ERC165 {
    IDigitalDustDAO public dao;
    ISocialToken public tokenContract;
    //bytes4 iSocialTokenHash;
    ISocialTokenNFT public nftContract;
    //bytes4 iSocialTokenNFTHash;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    bool private initialized;

    constructor(address dao_, uint256 daoId_) {
        dao = IDigitalDustDAO(dao_);
        daoId = daoId_;
        //tokenContract = ISocialToken(address(0));

        // iSocialTokenHash = type(ISocialTokenManager).interfaceId;
        // iSocialTokenNFTHash = type(ISocialTokenNFT).interfaceId;
    }

    modifier init2 {
        require(initialized, "Token contracts not init2");
        _;
    }

    // modifier onlyElders {
    //     require(dao.rightsOf(daoId, _msgSender()) >= 500, "Not enough rights to update");
    //     _;
    // }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function initialize(address tokenAddr, address nftAddr) public {
        require(ISocialToken(tokenAddr).supportsInterface(type(ISocialToken).interfaceId)
            && ISocialTokenNFT(nftAddr).supportsInterface(type(ISocialTokenNFT).interfaceId));
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);
    }

    function setTokenManager(address contractAddr) public init2 returns (address) {
        this.authorize(_msgSender(), Sensitivity.Elder);
        // require(
        //     SocialTokenManager(contractAddr).supportsInterface(iSocialTokenHash),
        //     "Contract must support ISocialTokenManager"
        // );

        tokenContract.setManager(contractAddr, false);
        return contractAddr;
    }

    function setNFT(address contractAddr) public init2 returns (address) {
        this.authorize(_msgSender(), Sensitivity.Elder);
        // require(
        //     SocialTokenNFT(contractAddr).supportsInterface(iSocialTokenNFTHash),
        //     "Contract must support ISocialTokenNFT"
        // );

        tokenContract.setNFT(contractAddr);
        return contractAddr;
    }

    function authorize(address source, address target, Sensitivity level) external view {
        if (level == Sensitivity.Basic) {
            require(dao.rightsOf(daoId, source) >= 100 && dao.rightsOf(daoId, target) >= 100 && dao.penaltyOf(daoId, source) == 0 && dao.penaltyOf(daoId, target) == 0, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(dao.rightsOf(daoId, source) >= 400 && dao.rightsOf(daoId, target) >= 400 && dao.penaltyOf(daoId, source) < 400 && dao.penaltyOf(daoId, target) < 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(dao.rightsOf(daoId, source) >= 500 && dao.rightsOf(daoId, target) >= 500 && dao.penaltyOf(daoId, source) < 500 && dao.penaltyOf(daoId, target) < 500, UNAUTHORIZED);
        }
        else { // invalid input, deny
            require(false, UNAUTHORIZED);
        }
    }

    function authorize(address source, Sensitivity level) external view {
        if (level == Sensitivity.Basic) {
            require(dao.rightsOf(daoId, source) >= 100 && dao.penaltyOf(daoId, source) == 0, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(dao.rightsOf(daoId, source) >= 400 && dao.penaltyOf(daoId, source) < 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(dao.rightsOf(daoId, source) >= 500 && dao.penaltyOf(daoId, source) < 500, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(dao.rightsOf(daoId, source) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.NFTContract) {
            require(source == address(nftContract), UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(source == address(tokenContract), UNAUTHORIZED);
        }
        else { // invalid input, deny
            require(false, UNAUTHORIZED);
        }
    }

    function adjustInterest() external view {
        // not implemented in this version
    }

}
