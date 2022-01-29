// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "./ISocialTokenManager.sol";
import "./ISocialTokenNFT.sol";
import "./ISocialToken.sol";

abstract contract LongTailSocialToken is ISocialToken, ERC777 {

// framerate, interest, adding and redeeming stakes, mining
    struct StakeDataPointer {
        address owner;
        uint32 interestRate;
        uint64 index;
   }

    struct StakeData {
        uint64 start;
        uint64 end;
        uint128 index;
        uint256 principal;
    }

    uint private constant MAXIMUM_STAKE_DAYS = 5844;
    uint private constant MININUM_STAKE_DAYS = 30;
    uint private constant MININUM_STAKE_AMOUNT = 100000000000;

    mapping(uint64 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;

    uint256 private START_TIME;

    uint64 private lastInterestAdjustment;
    uint64 private lastCompletedDistribution;
    uint64 private rewardPerMiningTask;
    uint64 private miningGasReserve;

    uint64 private baseInterestRate;
    uint64 private linearInterestBonus;
    uint64 private quadraticInterestBonus;


    ISocialTokenManager private manager;
    //ISocialTokenNFT private nftContract;

    constructor(address manager_, address[] memory defaultOperators_) 
        ERC777("Long Tail Social Token", "LTST", defaultOperators_) {

        manager = ISocialTokenManager(manager_);

        START_TIME = block.timestamp - (block.timestamp % 1 days);
        lastInterestAdjustment = type(uint64).max;

        // Pick some default values
        baseInterestRate = 50;
        linearInterestBonus = 25;
        quadraticInterestBonus = 10;
        rewardPerMiningTask = 50;
    }

    function setManager(address newManager, bool startInterestAdjustment) external {
        require(_msgSender() == address(manager));
        manager = ISocialTokenManager(newManager);
                
        if (startInterestAdjustment)
            lastInterestAdjustment = 0;
    }

    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint64 miningReward, uint64 miningReserve) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        baseInterestRate = base;
        linearInterestBonus = linear;
        quadraticInterestBonus = quadratic;
        rewardPerMiningTask = miningReward;
        miningGasReserve = miningReserve;
    }

    function getInterestRates() public view returns(uint64, uint64, uint64, uint64, uint64) {
        return (baseInterestRate, linearInterestBonus, quadraticInterestBonus, rewardPerMiningTask, miningGasReserve);
    }

    function stake(uint256 amount, uint16 numberOfDays) public returns(uint64) {
        // cache refrence variables
        address stakeAccount = _msgSender();
        uint64 today = getCurrentDay();
        uint64 endDay = today + numberOfDays;
        uint256 accountIndex = stakesByAccount[stakeAccount].length;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(amount >= MININUM_STAKE_AMOUNT);
        require(balanceOf(stakeAccount) >= amount);
        require(numberOfDays <= MAXIMUM_STAKE_DAYS); 
        require(numberOfDays >= MININUM_STAKE_DAYS);
        require(accountIndex <= type(uint64).max);
        require(endDayIndex <= type(uint128).max);

        // populate stake data
        stakesByEndDay[endDay].push(StakeDataPointer(
            stakeAccount,
            calculateInterestRate(stakeAccount, numberOfDays),
            uint64(accountIndex)
        ));

        stakesByAccount[stakeAccount].push(StakeData(
            today, 
            endDay,
            uint128(endDayIndex),
            amount
        ));

        // send 
        _send(stakeAccount, address(this), amount, "", "", true);

        emit Staked(stakeAccount, numberOfDays, endDay, amount, stakesByEndDay[endDay][endDayIndex].interestRate, uint64(accountIndex));

        return uint64(accountIndex);
    }

    function unstake(uint64 stakeNumber) public {
        // cache refrence variables
        address stakeAccount = _msgSender();
        uint256 principal = stakesByAccount[stakeAccount][stakeNumber].principal;

        // ensure outputs within range 
        require(principal > 0);
        
        // calculate the reward
        (bool positive, uint256 interest) = calculateInterest(
            stakesByAccount[stakeAccount][stakeNumber].start,
            stakesByAccount[stakeAccount][stakeNumber].end,
            stakesByEndDay[stakesByAccount[stakeAccount][stakeNumber].end][stakesByAccount[stakeAccount][stakeNumber].index].interestRate,
            stakesByAccount[stakeAccount][stakeNumber].principal);

        // delete the stake data
        delete(stakesByEndDay[stakesByAccount[stakeAccount][stakeNumber].end][stakesByAccount[stakeAccount][stakeNumber].index]);
        delete(stakesByAccount[stakeAccount][stakeNumber]);

        // distribute the funds
        if (positive) {
            _send(address(this), stakeAccount, principal, "", "", true);
            _mint(stakeAccount, interest, "", "");
        }
        else {
            _send(address(this), stakeAccount, principal - interest, "", "", true);
            _burn(address(this), interest, "", "");
        }

        // emit events
        unchecked { // overflow is very remotely possible here, but should not cause the function to revert since this is not essential functionality
            emit RedeemedStake(stakeAccount, principal, positive ? int256(interest) : (int256(interest) * -1));
        } 
    }

    function mine() public {
        require(balanceOf(_msgSender()) > 0);

        uint64 today = getCurrentDay();
        uint64 tasksCompleted = 0;
        StakeDataPointer memory currentStake;
        StakeData memory accountStake;

        // adjust interest (if needed)
        if (lastInterestAdjustment < today) {
            manager.adjustInterest();
            tasksCompleted++;
        }

        // reward ended stakes to people
        for (uint64 i = lastCompletedDistribution;i <= today;i++) {
            while (stakesByEndDay[i].length > 0 && gasleft() >= miningGasReserve) {
                currentStake = stakesByEndDay[i][stakesByEndDay[i].length - 1];
                stakesByEndDay[i].pop();
                if (currentStake.owner != address(0)) {
                    accountStake = stakesByAccount[currentStake.owner][currentStake.index];
                    delete(stakesByAccount[currentStake.owner][currentStake.index]);

                    _send(address(this), currentStake.owner, accountStake.principal, "", "", true);
                    _mint(currentStake.owner, _fullInterest(accountStake.end - accountStake.start, currentStake.interestRate, accountStake.principal), "", "");

                    tasksCompleted++;
                }
            }
        }

        if (tasksCompleted > 0) {
            _mint(_msgSender(), rewardPerMiningTask * tasksCompleted, "", "");
            emit MiningReward(_msgSender(), tasksCompleted, rewardPerMiningTask * tasksCompleted);
        }
    }

    function forge(address account, int256 amount) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.NFTContract);
        if (amount > 0) {
            _burn(account, uint256(amount), "", "");
        }
        else if (amount < 0) {
            _mint(account, uint256(-amount), "", "");
        }
    }

    function getStakeStart (address account, uint64 id) public view returns(uint64) {
        return stakesByAccount[account][id].start;
    }

    function getStakeEnd (address account, uint64 id) public view returns(uint64) {
        return stakesByAccount[account][id].end;
    }

    function getStakeInterestRate (address account, uint64 id) public view returns(uint32) {
        return stakesByEndDay[stakesByAccount[account][id].end][stakesByAccount[account][id].index].interestRate;
    }

    function getStakePrincipal (address account, uint64 id) public view returns(uint256) {
        return stakesByAccount[account][id].principal;
    }

    function getCurrentDay() public view returns(uint64) {
        return uint64((block.timestamp - START_TIME) / 1 days);
    }

    function calculateInterest(uint64 start, uint64 end, uint32 interestRate, uint256 principal) public view returns(bool, uint256) {
        uint64 halfStakeLength = (end - start) / 2;
        uint64 timeStaked = getCurrentDay() - start;
        uint256 payoff = _fullInterest(end - start, interestRate, principal);
        if (timeStaked < halfStakeLength) {
            return (false, (payoff * timeStaked) / halfStakeLength);
        }
        else {
            return (true, (payoff * (timeStaked - halfStakeLength)) / halfStakeLength);
        }
    }

    function _fullInterest(uint64 duration, uint32 interestRate, uint256 principal) private pure returns(uint256) {
        return (interestRate * duration * principal) / type(uint32).max;
    }

    function calculateInterestRate(address account, uint64 numberOfDays) public view returns(uint32) {
        uint256 interest = baseInterestRate + uint256(linearInterestBonus * numberOfDays) + uint256(quadraticInterestBonus * numberOfDays * numberOfDays) + uint256(manager.getNftContract().interestBonus(account));
        // cap the value at what can be held in a uint64 and downcast it into a uint32
        return interest > type(uint64).max ? type(uint32).max : uint32(interest / type(uint32).max);
    }

    function getNumMiningTasks() public view returns(uint256) {
        uint64 today = getCurrentDay();
        uint256 numTasks = lastInterestAdjustment < today ? 1 : 0;
        for (uint64 i = lastCompletedDistribution;i <= today;i++) {
            numTasks = numTasks + stakesByEndDay[i].length;
        }
        return numTasks;
    }

    function transfer(address recipient, uint256 amount) public virtual override(ERC777) returns (bool) {
        manager.authorize(_msgSender(), recipient, ISocialTokenManager.Sensitivity.Basic);
        return super.transfer(recipient, amount);
    }

    function send(address recipient, uint256 amount, bytes memory data) public virtual override(ERC777) {
        manager.authorize(_msgSender(), recipient, ISocialTokenManager.Sensitivity.Basic);
        super.send(recipient, amount, data);
    }
}