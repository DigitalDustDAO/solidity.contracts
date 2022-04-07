// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract SocialTokenManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO internal daoContract;
    ISocialToken internal tokenContract;
    ISocialTokenNFT internal nftContract;
    IERC20 internal auxTokenContract;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    string constant private INVALID_INTERFACE = "Invalid interface";

    constructor(address dao_, uint256 daoId_, address tokenAddr, address nftAddr) {
        daoContract = IDigitalDustDAO(dao_);
        daoId = daoId_;
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // Time to pass to a new manager
    function upgrade(address newManager, address payable sendTo, bool startInterestAdjustment) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), INVALID_INTERFACE);

        tokenContract.setManager(newManager, startInterestAdjustment);
        nftContract.setManager(newManager);

        selfdestruct(sendTo);
    }

    function setAuxTokenContract(address contractAddress) public {
        this.authorize(_msgSender(), Sensitivity.Elder);

        auxTokenContract = IERC20(contractAddress);
    }

    function hasAuxToken(address account) public view returns(bool) {
        if (address(auxTokenContract) == address(0)) {
            return false;
        }
        else {
            return auxTokenContract.balanceOf(account) > 0;
        }
    }

    function getDaoContract() public view returns(IDigitalDustDAO) {
        return daoContract;
    }

    function getTokenContract() public view returns(ISocialToken) {
        return tokenContract;
    }

    function getNftContract() public view returns(ISocialTokenNFT) {
        return nftContract;
    }

    function authorize(address account, Sensitivity level) external view {
        if (level == Sensitivity.Council) {
            require(daoContract.accessOf(account, daoId) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.accessOf(account, daoId) >= 500, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Maintainance) {
            require(daoContract.rightsOf(account, daoId) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.AwardableContract) {
            require(account == address(nftContract), UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(account == address(tokenContract), UNAUTHORIZED);
        }
        else if (level != Sensitivity.Basic) {
            revert(UNAUTHORIZED); // invalid input, deny
        }
    }

    function adjustInterest() external view {
        // not implemented in this version
    }
}
