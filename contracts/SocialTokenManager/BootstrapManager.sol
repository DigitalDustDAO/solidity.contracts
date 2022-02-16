// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract BootstrapManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO private daoContract;
    ISocialToken private tokenContract;
    ISocialTokenNFT private nftContract;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    string constant private INVALID_INTERFACE = "Invalid interface";
    bool private initialized;

    constructor(address dao_, uint256 daoId_) {
        daoContract = IDigitalDustDAO(dao_);
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
    function upgrade(address newManager, address payable sendTo) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(initialized);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), INVALID_INTERFACE);

        tokenContract.setManager(newManager, false);
        nftContract.setManager(newManager);

        initialized = false;
        selfdestruct(sendTo);
    }

    function getDaoContract() external view returns(IDigitalDustDAO) {
        return daoContract;
    }

    function getTokenContract() external view returns(ISocialToken) {
        require(initialized);
        return tokenContract;
    }

    function getNftContract() external view returns(ISocialTokenNFT) {
        require(initialized);
        return nftContract;
    }

    function authorize(address account, Sensitivity level) external view {
        if (level == Sensitivity.Basic) {
            require(daoContract.accessOf(daoId, account) >= 100, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Council) {
            require(daoContract.accessOf(daoId, account) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.accessOf(daoId, account) >= 500, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(daoContract.rightsOf(daoId, account) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.NFTContract) {
            require(account == address(nftContract), UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(account == address(tokenContract), UNAUTHORIZED);
        }
        else { // invalid input, deny
            revert(UNAUTHORIZED);
        }
    }

    function adjustInterest() external view {
        // not implemented in this version
    }

}
