// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./ISocialTokenManager.sol";
import "./ISocialToken.sol";
import "./ISocialTokenNFT.sol";
import "./IDigitalDustDAO.sol";

abstract contract SocialTokenManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO public dao;
    ISocialToken private tokenContract;
    ISocialTokenNFT private nftContract;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    bool private initialized;

    constructor(address dao_, uint256 daoId_) {
        dao = IDigitalDustDAO(dao_);
        daoId = daoId_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function initialize(address tokenAddr, address nftAddr) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(ISocialToken(tokenAddr).supportsInterface(type(ISocialToken).interfaceId)
            && ISocialTokenNFT(nftAddr).supportsInterface(type(ISocialTokenNFT).interfaceId));
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);

        initialized = true;
    }

    // Time to pass to a new manager
    function deprecateSelf(address newManager, address payable sendTo, bool startInterestAdjustment) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(initialized && ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId));

        tokenContract.setManager(newManager, startInterestAdjustment);
        nftContract.setManager(newManager);

        selfdestruct(sendTo);
    }

    function getTokenContract() external view returns(ISocialToken) {
        return tokenContract;
    }

    function getNftContract() external view returns(ISocialTokenNFT) {
        return nftContract;
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
