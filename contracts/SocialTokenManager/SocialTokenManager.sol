// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract SocialTokenManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO internal daoContract;
    ISocialToken internal tokenContract;
    ISocialTokenNFT internal nftContract;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    string constant private INVALID_INTERFACE = "Invalid interface";
    bool internal initialized;

    constructor(address dao_, uint256 daoId_) {
        daoContract = IDigitalDustDAO(dao_);
        daoId = daoId_;
    }

    function getInterfaceId() public pure returns (bytes4) {
        return type(ISocialTokenManager).interfaceId;
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
        require(
            // ISocialToken(tokenAddr).supportsInterface(type(ISocialToken).interfaceId) &&
            ISocialTokenNFT(nftAddr).supportsInterface(type(ISocialTokenNFT).interfaceId),
            INVALID_INTERFACE
        );
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);

        initialized = true;
    }

    // Time to pass to a new manager
    function deprecateSelf(address newManager, address payable sendTo, bool startInterestAdjustment) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        // require(initialized && ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), INVALID_INTERFACE);

        tokenContract.setManager(newManager, startInterestAdjustment);
        nftContract.setManager(newManager);

        selfdestruct(sendTo);
    }

    function getDaoContract() external view returns(IDigitalDustDAO) {
        return daoContract;
    }

    function getTokenContract() external view returns(ISocialToken) {
        return tokenContract;
    }

    function getNftContract() external view returns(ISocialTokenNFT) {
        return nftContract;
    }

    function authorize(address source, address target, Sensitivity level) external view {
        if (level == Sensitivity.Basic) {
            require(daoContract.accessOf(daoId, source) >= 100 && daoContract.accessOf(daoId, target) >= 100, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(daoContract.accessOf(daoId, source) >= 400 && daoContract.accessOf(daoId, target) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.accessOf(daoId, source) >= 500 && daoContract.accessOf(daoId, target) >= 500, UNAUTHORIZED);
        }
        else { // invalid input, deny
            revert(UNAUTHORIZED);
        }
    }

    function authorize(address source, Sensitivity level) external view {
        if (level == Sensitivity.Basic) {
            require(daoContract.accessOf(daoId, source) >= 100, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(daoContract.accessOf(daoId, source) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.accessOf(daoId, source) >= 500, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(daoContract.rightsOf(daoId, source) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.NFTContract) {
            require(source == address(nftContract), UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(source == address(tokenContract), UNAUTHORIZED);
        }
        else { // invalid input, deny
            revert(UNAUTHORIZED);
        }
    }

    function adjustInterest() external view {
        // not implemented in this version
    }

}
