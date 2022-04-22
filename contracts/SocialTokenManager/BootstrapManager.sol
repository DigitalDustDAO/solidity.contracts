// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../LiquidityPool/ISocialTokenLiquidityPool.sol";
import "../SocialToken/ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract BootstrapManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO private immutable daoContract;
    ISocialToken private tokenContract;
    ISocialTokenNFT private nftContract;
    IERC20 private auxTokenContract;

    ISocialTokenLiquidityPool[] private liquidityPools;

    uint256 public immutable daoId;
    uint32 private constant CONTRACT_RIGHTS = 488;

    string constant private UNAUTHORIZED = "Not authorized";
    string constant private INVALID_INTERFACE = "Invalid interface";
    string constant private NOT_INITIALIZED = "Contract not enabled";

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
        // require(
        //     // ISocialToken(tokenAddr).supportsInterface(type(ISocialToken).interfaceId) &&
        //     ISocialTokenNFT(nftAddr).supportsInterface(type(ISocialTokenNFT).interfaceId),
        //     INVALID_INTERFACE
        // );
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);

        initialized = true;
    }

    // Time to pass to a new manager
    function upgrade(address newManager, address payable sendTo) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(initialized, NOT_INITIALIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), INVALID_INTERFACE);

        tokenContract.setManager(newManager, false);
        nftContract.setManager(newManager);
        for (uint256 i = 0;i < liquidityPools.length;i++) {
            if (address(liquidityPools[i]) != address(0)) {
                liquidityPools[i].setManager(newManager);
            }
        }

        initialized = false;
        selfdestruct(sendTo);
    }

    function setAuxTokenContract(address contractAddress) public {
        this.authorize(_msgSender(), Sensitivity.Elder);

        auxTokenContract = IERC20(contractAddress);
    }

    function registerLiquidityPool() external {
        this.authorize(_msgSender(), Sensitivity.AwardableContract);
        require(IERC165(_msgSender()).supportsInterface(type(ISocialTokenLiquidityPool).interfaceId));

        liquidityPools.push(ISocialTokenLiquidityPool(_msgSender()));
    }

    function unregisterLiquidityPool(address account) external {
        this.authorize(_msgSender(), Sensitivity.Elder);
        for (uint256 i = 0;i < liquidityPools.length;i++) {
            if (address(liquidityPools[i]) == account) {
                liquidityPools[i] = ISocialTokenLiquidityPool(address(0));
            }
        }
    }

    function hasAuxToken(address) public pure returns(bool) {
        return true;
    }

    function getDaoContract() public view returns(IDigitalDustDAO) {
        return daoContract;
    }

    function getTokenContract() public view returns(ISocialToken) {
        require(initialized, NOT_INITIALIZED);
        return tokenContract;
    }

    function getNftContract() public view returns(ISocialTokenNFT) {
        require(initialized, NOT_INITIALIZED);
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
            require(daoContract.rightsOf(account, daoId) == CONTRACT_RIGHTS, UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenContract) {
            require(account == address(tokenContract), UNAUTHORIZED);
        }
        else { // invalid input, deny
            revert(UNAUTHORIZED);
        }
    }

    function authorizeTx(address source, address destination) external view {
        require(daoContract.accessOf(source, daoId) >= 1 && daoContract.accessOf(destination, daoId) >= 1, UNAUTHORIZED);
    }

    function adjustInterest() external view {
        // not implemented in this version
    }

}
