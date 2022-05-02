// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC20 {
    mapping(uint256 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;

    ISocialTokenManager public manager;

    string private STAKE_LIMIT = "Stake limit reached";
    string private UNAUTHORIZED = "Not authorized";

    bool private mining;
    uint256 internal lastInterestAdjustment;
    uint256 internal lastCompletedDistribution;
    uint256 internal rewardPerMiningTask;
    uint256 internal miningGasReserve;
    uint256 internal baseInterestRate;
    uint256 internal linearInterestBonus;
    uint256 internal quadraticInterestBonus;
    uint256 internal maximumStakeDays;
    uint256 internal mininumStakeDays;
    uint256 internal mininumStakeAmount;
    uint256 internal immutable START_TIME;

    constructor(address manager_) ERC20("Long Tail Social Token", "LTST") {

        manager = ISocialTokenManager(manager_);

        START_TIME = block.timestamp - 2 hours - (block.timestamp % 1 days);
        lastInterestAdjustment = type(uint64).max;

        // Pick some very low default values
        baseInterestRate = 50000000;
        linearInterestBonus = 25000000;
        quadraticInterestBonus = 10000000;
        rewardPerMiningTask = 10**18;
        miningGasReserve = 1500;

        mininumStakeAmount = 3125000000000000; // 1/32th of one token
        mininumStakeDays = 7;
        maximumStakeDays = 5844; // 16 years
    }

    function setManager(address newManager, bool startInterestAdjustment) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), "Interface unsupported");

        manager = ISocialTokenManager(newManager);
                
        if (startInterestAdjustment)
            lastInterestAdjustment = 0;
    }

    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint256 miningReward, uint256 miningReserve) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        baseInterestRate = base;
        linearInterestBonus = linear;
        quadraticInterestBonus = quadratic;
        rewardPerMiningTask = miningReward;
        miningGasReserve = miningReserve;
    }

    function setContractConstraints(uint256 minStakeAmount, uint64 minStakeDays, uint64 maxStakeDays) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        mininumStakeAmount = minStakeAmount;
        mininumStakeDays = minStakeDays;
        maximumStakeDays = maxStakeDays;
    }

    function stake(uint256 amount, uint256 numberOfDays) public returns(uint32) {
        // cache refrence variables
        uint256 today = getCurrentDay();
        uint256 endDay = today + numberOfDays;
        uint256 accountIndex = stakesByAccount[_msgSender()].length;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(amount >= mininumStakeAmount, "Stake too small");
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");
        require(numberOfDays <= maximumStakeDays, "Stake too long");
        require(numberOfDays >= mininumStakeDays, "Stake too short");
        require(accountIndex <= type(uint32).max, STAKE_LIMIT);
        require(endDayIndex <= type(uint128).max, STAKE_LIMIT);

        // populate stake data
        stakesByEndDay[endDay].push(StakeDataPointer(
            _msgSender(),
            calculateInterestRate(_msgSender(), numberOfDays),
            uint32(accountIndex)
        ));

        stakesByAccount[_msgSender()].push(StakeData(
            uint64(today),
            uint64(endDay),
            uint128(endDayIndex),
            amount
        ));

        // send the stake to this contract
        _transfer(_msgSender(), address(this), amount);

        emit Staked(
            _msgSender(),
            uint64(numberOfDays),
            uint64(endDay),
            amount,
            stakesByEndDay[endDay][endDayIndex].interestRate,
            uint32(accountIndex)
        );

        return uint32(accountIndex);
    }

    function unstake(uint32 stakeNumber) public virtual {
        // cache refrence variables
        address stakeAccount = _msgSender();
        StakeData memory myStake = stakesByAccount[stakeAccount][stakeNumber];

        // ensure outputs within range 
        require(myStake.principal > 0);
        
        // calculate the reward
        int256 interest = calculateInterest(myStake.start, myStake.end, getCurrentDay(),
            stakesByEndDay[myStake.end][myStake.index].interestRate, myStake.principal);

        // delete the stake data
        delete(stakesByEndDay[myStake.end][myStake.index]);
        delete(stakesByAccount[stakeAccount][stakeNumber]);

        // distribute the funds
        if (interest >= 0) {
            _transfer(address(this), stakeAccount, myStake.principal);
            _mint(stakeAccount, uint256(interest));
        }
        else if (int256(myStake.principal) + interest > 0) {
            _transfer(address(this), stakeAccount, uint256(int256(myStake.principal) + interest));
            _burn(address(this), uint256(-interest));
        }
        else { // exceedingly unlikely... but not impossible
            _burn(address(this), myStake.principal);
        }

        // emit events
        emit RedeemedStake(stakeAccount, myStake.principal, interest);
    }

    function mine() public virtual {
        require(balanceOf(_msgSender()) > 0, UNAUTHORIZED);
        manager.authorizeTx(address(this), _msgSender(), rewardPerMiningTask);

        mining = true;
        uint256 tasksCompleted;
        uint256 interest;
        StakeDataPointer storage currentStake;
        StakeData storage accountStake;

        // adjust interest (if needed)
        if (lastInterestAdjustment < getCurrentDay()) {
            tasksCompleted = manager.adjustInterest();
        }

        // reward ended stakes to people
        for (uint256 i = lastCompletedDistribution;i <= getCurrentDay();i++) {
            while (stakesByEndDay[i].length > 0 && gasleft() >= miningGasReserve) {
                currentStake = stakesByEndDay[i][stakesByEndDay[i].length - 1];
                if (currentStake.owner != address(0)) {
                    accountStake = stakesByAccount[currentStake.owner][currentStake.index];

                    interest = _fullInterest(accountStake.end - accountStake.start, currentStake.interestRate, accountStake.principal);
                    _transfer(address(this), currentStake.owner, accountStake.principal);
                    _mint(currentStake.owner, interest);

                    delete(stakesByAccount[currentStake.owner][currentStake.index]);
                    tasksCompleted++;
                }

                stakesByEndDay[i].pop();
            }
        }

        if (tasksCompleted > 0) {
            _mint(_msgSender(), rewardPerMiningTask * tasksCompleted);
            emit MiningReward(_msgSender(), uint64(tasksCompleted), rewardPerMiningTask * tasksCompleted);
        }

        mining = false;
    }

    function award(address account, int256 amount, string memory explanation) virtual external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.AwardableContract);

        if (amount < 0) {
            _burn(account, uint256(-amount));
            emit AwardToAddress(account, amount, explanation);
        }
        else if (amount > 0) {
            _mint(account, uint256(amount));
            emit AwardToAddress(account, amount, explanation);
        }
    }

    function getNumMiningTasks() public view returns(uint256) {
        uint256 today = getCurrentDay();
        uint256 numTasks = lastInterestAdjustment < today ? 1 : 0;
        for (uint256 i = lastCompletedDistribution;i <= today;i++) {
            numTasks = numTasks + stakesByEndDay[i].length;
        }
        return numTasks;
    }

    function getContractInterestRates() public view returns(uint64, uint64, uint64, uint256, uint256) {
        return (
            uint64(baseInterestRate),
            uint64(linearInterestBonus),
            uint64(quadraticInterestBonus),
            rewardPerMiningTask,
            miningGasReserve
        );
    }

    function getContractConstraints() public view returns(uint256, uint64, uint64) {
        return (mininumStakeAmount, uint64(mininumStakeDays), uint64(maximumStakeDays));
    }

    function getStakeValues (address account, uint32 id) public view returns(uint64, uint64, uint64, uint256) {
        return (
            stakesByAccount[account][id].start,
            stakesByAccount[account][id].end,
            stakesByEndDay[stakesByAccount[account][id].end][stakesByAccount[account][id].index].interestRate,
            stakesByAccount[account][id].principal
        );
    }

    function getCurrentDay() public virtual view returns(uint256) {
        return (block.timestamp - START_TIME) / 1 days;
    }

    function getVotingPower(address account, uint64 minValidStakeLength, uint32[] memory stakeIds) public view returns(uint256 votingPower) {
        StakeData storage thisStake;

        for(uint256 i = 0; i < stakeIds.length; i++) {
            thisStake = stakesByAccount[account][stakeIds[i]];
            if (thisStake.principal > 0 && thisStake.end - thisStake.start >= minValidStakeLength) {
                votingPower += (_fullInterest(_votingWeight(thisStake.start, thisStake.end, getCurrentDay()),  
                        stakesByEndDay[thisStake.end][thisStake.index].interestRate, thisStake.principal));
            }
        }
    }

    // This function gets the interest that will be earned if you withdraw a stake on a particular day.
    //  If you withdraw the same day you stake then you don't get any penality.
    function calculateInterest(uint256 start, uint256 end, uint256 dayOfWithdrawal, uint256 interestRate, uint256 principal) 
            public pure returns(int256) {
        uint256 halfStakeLength = (end - start) / 2;
        uint256 timeStaked = dayOfWithdrawal - start;
        uint256 full = _fullInterest(end - start, interestRate, principal);

        if (dayOfWithdrawal == start) {
            return 0;
        }
        else if (timeStaked < halfStakeLength) {
            return int256((full * timeStaked) / halfStakeLength) * -1;
        }
        else {
            return int256((full * (timeStaked - halfStakeLength)) / halfStakeLength);
        }
    }

    function calculateInterestRate(address account, uint256 numberOfDays) public view returns(uint64) {
        // These values should never be set high enough that they *could* overflow. If they do, however, then it's better to rollover than to revert.
        unchecked {
            uint256 interest = (
                baseInterestRate +
                (linearInterestBonus * numberOfDays) +
                (quadraticInterestBonus * numberOfDays * numberOfDays) +
                manager.getNftContract().interestBonus(account)
            );
            // cap the value at what can be held in a uint64
            return interest > type(uint64).max ? type(uint64).max : uint64(interest);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (!mining) { manager.authorizeTx(from, to, amount); }
    }

    function _votingWeight(uint256 start, uint256 end, uint256 current) private pure returns(uint256) {
        uint256 totalDays = end - start;
        uint256 daysMature = current - start;

        return daysMature <= totalDays / 2 ? daysMature : totalDays - daysMature;
    }

    function _fullInterest(uint256 duration, uint256 interestRate, uint256 principal) private pure returns(uint256) {
        return (interestRate * duration * principal) / type(uint64).max;
    }
}
