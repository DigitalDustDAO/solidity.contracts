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

contract UniswapLiquidityPool is ISocialTokenLiquidityPool, ERC165 {

    //IUniswapV2Factory immutable private uniV2FactoryAddr;
    IUniswapV2Router02 immutable public uniV2RouterAddress;
    IUniswapV2Pair immutable public pairAddress;

    ISocialTokenManager public manager;

    // the normal factory address is 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    // the normal router address is  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    constructor(address managerAddress, address routerAddress) {
        manager = ISocialTokenManager(managerAddress);
        uniV2RouterAddress = IUniswapV2Router02(routerAddress);

         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Pair(IUniswapV2Factory(uniV2RouterAddress.factory()).createPair(address(this), uniV2RouterAddress.WETH()));
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), "Interface unsupported");

        manager = ISocialTokenManager(newManager);
    }

    
}