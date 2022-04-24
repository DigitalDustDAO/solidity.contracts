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

contract UniswapLiquidityPool is ISocialTokenLiquidityPool, Context, ERC165 {

    string private constant UNAUTHORIZED = "Not authorized";
    
    IUniswapV2Router02 immutable public uniV2RouterAddress;
    IUniswapV2Pair immutable public pairAddress;
    ISocialTokenManager public manager;

    uint256 private immutable START_TIME;

    mapping(address => Stake) private stakes;
    uint64 public dailyInterestRate;
    bool private funded;

    // the normal router address is 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    // the normal weth address is   0xc778417E063141139Fce010982780140Aa0cD5Ab
    // Only pass in a pair address if one has already been created, otherwise leave as zero.
    constructor(address managerAddress, address routerAddress, address existingPairAddress) {
        manager = ISocialTokenManager(managerAddress);
        uniV2RouterAddress = IUniswapV2Router02(routerAddress);

        if (existingPairAddress == address(0)) {
            // Create a uniswap pair for this new token
            existingPairAddress = IUniswapV2Factory(uniV2RouterAddress.factory()).createPair(address(manager.getTokenContract()), uniV2RouterAddress.WETH());
        }
        
        pairAddress = IUniswapV2Pair(existingPairAddress);
        
        START_TIME = block.timestamp - (block.timestamp % 1 days);
        dailyInterestRate = 4294967296;
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);

        manager = ISocialTokenManager(newManager);
        manager.registerLiquidityPool();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenLiquidityPool).interfaceId
            || super.supportsInterface(interfaceId);
    }
    
    // Set up, can only be called once
    function fundPool(uint256 tokenAmount) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Elder);
        require(!funded);

        manager.getTokenContract().award(address(this), int256(tokenAmount), "Uniswap pool initial funding");

        IERC20 tokenContract = IERC20(address(manager.getTokenContract()));
        tokenContract.approve(address(pairAddress), tokenAmount);

        IERC20 wethAddress = IERC20(uniV2RouterAddress.WETH());
        uint256 wethAmount = wethAddress.balanceOf(address(this));        
        wethAddress.approve(address(pairAddress), wethAmount);

        uniV2RouterAddress.addLiquidity(address(tokenContract), uniV2RouterAddress.WETH(), 
            tokenAmount, wethAmount, tokenAmount, wethAmount, address(this), block.timestamp + 1024);
        
        manager.registerLiquidityPool();
        funded = true;
    }

    // Council function
    function setInterestRate(uint64 newDailyInterestRate) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        dailyInterestRate = newDailyInterestRate;
    }

    // Getters
    function getCurrentDay() public virtual view returns(uint32) {
        return uint32((block.timestamp - START_TIME) / 1 days);
    }

    function getStakeData(address account) public view returns(uint160 principal, uint64 mininumInterestRate, uint256 uncollectedRewards) {
        Stake storage userStake = stakes[account];

        return (userStake.principal, userStake.interestRate, _calculateInterest(userStake.principal, 
            userStake.interestRate < dailyInterestRate ? userStake.interestRate : dailyInterestRate, 
            getCurrentDay() - userStake.startDay));
    }

    // User functions
    function stake(uint256 amount) public {
        Stake storage userStake = stakes[_msgSender()];

        require(amount > 0);
        require(pairAddress.balanceOf(_msgSender()) >= amount, "Not enough tokens");
        require(pairAddress.allowance(_msgSender(), address(this)) >= amount, "Authorization needed");
        require(amount + userStake.principal <= type(uint160).max);

        Stake memory origionalStake = userStake;

        userStake.interestRate = dailyInterestRate;
        userStake.startDay = getCurrentDay();
        userStake.principal += uint160(amount);
        
        pairAddress.transferFrom(_msgSender(), address(this), amount);
        _awardInterest(origionalStake);
    }

    function unstake(uint256 amount) public {
        Stake storage storedStake = stakes[_msgSender()];
        require(storedStake.principal > 0, "Account not staked");
        Stake memory userStake = storedStake;

        if (amount >= storedStake.principal) {
            delete(stakes[_msgSender()]);

            pairAddress.transfer(_msgSender(), userStake.principal);
            _awardInterest(userStake);
        }
        else {
            storedStake.interestRate = dailyInterestRate;
            storedStake.startDay = getCurrentDay();
            storedStake.principal -= uint160(amount);

            pairAddress.transfer(_msgSender(), amount);
            _awardInterest(userStake);
        }
    }

    function collectInterest() public {
        Stake memory userStake = stakes[_msgSender()];

        stakes[_msgSender()].interestRate = dailyInterestRate;
        stakes[_msgSender()].startDay = getCurrentDay();

        _awardInterest(userStake);
    }

    // Private functions
    function _calculateInterest(uint256 principal, uint64 rate, uint64 numberOfDays) private pure returns(uint256) {
        return (principal * rate * numberOfDays) / type(uint64).max;
    }

    function _awardInterest(Stake memory userStake) private {
        if (userStake.principal > 0 && userStake.startDay < getCurrentDay()) {
            uint256 interest = _calculateInterest(userStake.principal, 
                userStake.interestRate < dailyInterestRate ? userStake.interestRate : dailyInterestRate, 
                getCurrentDay() - userStake.startDay);

            uint256 LPToDistribute = pairAddress.balanceOf(address(this));
            if (LPToDistribute > 0) {
                pairAddress.transfer(_msgSender(), interest < LPToDistribute ? interest : LPToDistribute);
            }
            else {
                manager.getTokenContract().award(_msgSender(), int256(interest), "Uniswap staking reward");
            }
        }
    }
}
