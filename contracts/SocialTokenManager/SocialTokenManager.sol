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

contract SocialTokenManager is Context, ISocialTokenManager, ERC165 {
    IDigitalDustDAO private immutable daoContract;
    ISocialToken private immutable tokenContract;
    ISocialTokenNFT private immutable nftContract;
    IERC20 private immutable auxTokenContract;
    ISocialTokenLiquidityPool[] private liquidityPools;

    uint256 public immutable daoId;

    uint32 private constant CONTRACT_RIGHTS = 488;
    string private UNAUTHORIZED = "Not authorized";
    string private INVALID_INTERFACE = "Invalid interface";

    constructor(address daoAddr, uint256 daoIndex, address tokenAddr, address nftAddr, address auxTokenAddr) {
        daoContract = IDigitalDustDAO(daoAddr);
        daoId = daoIndex;
        tokenContract = ISocialToken(tokenAddr);
        nftContract = ISocialTokenNFT(nftAddr);
        auxTokenContract = IERC20(auxTokenAddr);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // Time to pass to a new manager
    function upgrade(address payable newManager, bool startInterestAdjustment) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), INVALID_INTERFACE);

        tokenContract.setManager(newManager, startInterestAdjustment);
        nftContract.setManager(newManager);
        for (uint256 i = 0;i < liquidityPools.length;i++) {
            liquidityPools[i].setManager(newManager);
        }

        selfdestruct(newManager);
    }

    function upgrade(address payable newManager) public {
        upgrade(newManager, false);
    }

    function registerLiquidityPool() external {
        this.authorize(_msgSender(), Sensitivity.AwardableContract);
        require(IERC165(_msgSender()).supportsInterface(type(ISocialTokenLiquidityPool).interfaceId));

        liquidityPools.push(ISocialTokenLiquidityPool(_msgSender()));
    }

    function auxToken(address account) public view returns(uint32) {
        if (address(auxTokenContract) == address(0)) {
            return 1;
        }
        else {
            return auxTokenContract.balanceOf(account) > 0 ? 1 : 0;
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
            require(daoContract.rightsOf(account, daoId) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.rightsOf(account, daoId) >= 500, UNAUTHORIZED);
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
        else {
            revert(UNAUTHORIZED); // invalid input, deny
        }
    }

    function authorizeTx(address, address, uint256) external view {}

    function adjustInterest(address, uint256) external view returns(uint256) {
        // not implemented in this version
        return 0;
    }
}
