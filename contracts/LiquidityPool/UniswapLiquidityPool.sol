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

    IUniswapV2Router02 immutable public uniV2RouterAddress;
    IUniswapV2Pair immutable public pairAddress;
    ISocialTokenManager public manager;

    uint256 private immutable START_TIME;

    mapping(address => Stake) private stakes;
    uint256 public LPToDistribute;
    uint128 public interestRate;
    uint64 public vestingPeriod;
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
        
        START_TIME = block.timestamp - 2 hours - (block.timestamp % 1 days);
        interestRate = 4294967296;
        vestingPeriod = 1;
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager), "Not authorized");

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
        tokenContract.approve(address(uniV2RouterAddress), tokenAmount);

        IERC20 wethAddress = IERC20(uniV2RouterAddress.WETH());
        uint256 wethAmount = wethAddress.balanceOf(address(this));        
        wethAddress.approve(address(uniV2RouterAddress), wethAmount);

        uniV2RouterAddress.addLiquidity(address(tokenContract), uniV2RouterAddress.WETH(), 
            tokenAmount, wethAmount, tokenAmount, wethAmount, address(this), block.timestamp + 16);
        
        LPToDistribute = pairAddress.balanceOf(address(this));
        manager.registerLiquidityPool();
        funded = true;
    }

    // Maintainance function
    function setInterestRate(uint128 newInterestRate, uint64 newVestingPeriod) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        interestRate = newInterestRate;
        vestingPeriod = newVestingPeriod;
    }

    // Getters
    function getCurrentDay() public virtual view returns(uint64 today) {
        today = uint64((block.timestamp - START_TIME) / 1 days);
    }

    function getStakeData(address account) public view returns(uint192 principal, uint256 uncollectedRewards) {
        Stake storage userStake = stakes[account];

        principal = userStake.principal;
        uncollectedRewards = _calculateInterest(userStake.principal, interestRate, getCurrentDay() - userStake.startDay);
    }

    // User functions
    function stake(uint192 amount) public {
        Stake storage storedStake = stakes[_msgSender()];

        require(amount > 0);
        require(pairAddress.balanceOf(_msgSender()) >= amount, "Not enough tokens");
        require(pairAddress.allowance(_msgSender(), address(this)) >= amount, "Authorization needed");
        require(amount + storedStake.principal <= type(uint192).max);

        if (storedStake.principal == 0) {
            storedStake.startDay = getCurrentDay() + vestingPeriod;
            storedStake.principal = amount;
        }
        else {
            _awardInterest(storedStake);

            if (storedStake.startDay < getCurrentDay() + vestingPeriod) {
                storedStake.startDay = getCurrentDay() + vestingPeriod;
            }

            storedStake.principal += amount;
        }

        pairAddress.transferFrom(_msgSender(), address(this), amount);

        emit Staked(_msgSender(), storedStake.startDay, storedStake.principal);
    }

    function unstake(uint256 amount) public {
        Stake storage storedStake = stakes[_msgSender()];
        require(storedStake.principal > 0, "Account not staked");
        
        _awardInterest(storedStake);

        if (amount >= storedStake.principal) {
            amount = storedStake.principal;
            delete(stakes[_msgSender()]);
            pairAddress.transfer(_msgSender(), amount);
        }
        else {
            if (storedStake.startDay < getCurrentDay()) {
                storedStake.startDay = getCurrentDay();
            }

            storedStake.principal -= uint192(amount);
            pairAddress.transfer(_msgSender(), amount);
        }
    }

    function collectInterest() public {
        _awardInterest(stakes[_msgSender()]);

        if (stakes[_msgSender()].startDay < getCurrentDay()) {
            stakes[_msgSender()].startDay = getCurrentDay();
        }
    }

    // Private functions
    function _calculateInterest(uint256 principal, uint256 rate, uint256 numberOfDays) private pure returns(uint256) {
        return (principal * rate * numberOfDays) / type(uint64).max;
    }

    function _awardInterest(Stake storage userStake) private {
        if (userStake.principal > 0 && userStake.startDay < getCurrentDay()) {
            uint256 interest = _calculateInterest(userStake.principal, interestRate, getCurrentDay() - userStake.startDay);

            if (LPToDistribute > 0) {
                if (interest > LPToDistribute) {
                    stakes[_msgSender()].principal += uint192(LPToDistribute);
                    interest -= LPToDistribute;
                    LPToDistribute = 0;
                }
                else {
                    stakes[_msgSender()].principal += uint192(interest);
                    LPToDistribute -= interest;
                    interest = 0;
                }
            }

            manager.getTokenContract().award(_msgSender(), int256(interest), "Uniswap staking reward");
        }
    }
}
