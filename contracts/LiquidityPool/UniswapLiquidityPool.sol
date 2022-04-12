// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../LiquidityPool/ISocialTokenLiquidityPool.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract UniswapLiquidityPool is ISocialTokenLiquidityPool, Context, ERC165 {

    string private constant UNAUTHORIZED = "Not authorized";
    
    IUniswapV2Router02 immutable public uniV2RouterAddress;
    IUniswapV2Pair immutable public pairAddress;
    ISocialTokenManager public manager;

    uint256 LPToDistribute;
    uint256 private immutable START_TIME;
    uint64 private dailyInterestRate;
    bool private funded;

    // the normal factory address is 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    // the normal router address is  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    constructor(address managerAddress, address routerAddress) {
        manager = ISocialTokenManager(managerAddress);
        uniV2RouterAddress = IUniswapV2Router02(routerAddress);

         // Create a uniswap pair for this new token
        pairAddress = IUniswapV2Pair(IUniswapV2Factory(uniV2RouterAddress.factory()).createPair(address(manager.getTokenContract()), uniV2RouterAddress.WETH()));

        START_TIME = block.timestamp - (block.timestamp % 1 days);
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), "Interface unsupported");

        manager = ISocialTokenManager(newManager);
    }

    function fundPool(uint256 tokenAmount, uint256 ethAmount) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Elder);
        require(!funded);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = 
            uniV2RouterAddress.addLiquidityETH(address(manager.getTokenContract()), tokenAmount, tokenAmount, ethAmount, address(this), block.timestamp);
        
        LPToDistribute = liquidity;
    }

    function refundAnyEth(address payable recipient) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Elder);

        recipient.transfer(address(this).balance);
    }

    function setInterestRate(uint64 newDailyInterestRate) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        dailyInterestRate = newDailyInterestRate;
    }

    function getCurrentDay() public virtual view returns(uint256) {
        return (block.timestamp - START_TIME) / 1 days;
    }

    function calculateInterest(uint256 principal, uint64 rate, uint64 numberOfDays) public pure returns(uint256) {
        return (principal * (rate ** numberOfDays)) / type(uint64).max;
    }
}