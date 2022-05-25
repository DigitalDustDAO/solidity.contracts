// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC20 {
    mapping(uint256 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => mapping(uint256 => StakeData)) private stakesByAccount;
    mapping(address => uint256) private nextStakeForAccount;

    ISocialTokenManager public manager;

    string private STAKE_LIMIT = "Stake limit reached";
    string private UNAUTHORIZED = "Not authorized";
    string private INVALID_INPUT = "Invalid input";

    bool private mining;
    uint256 internal lastInterestAdjustment;
    uint256 internal lastCompletedDistribution;
    uint256 internal rewardPerMiningTask;
    uint256 internal baseInterest;
    int256  internal quadraticInterest;
    uint256 internal linearInterest;
    uint256 internal maximumStakeDays;
    uint256 internal mininumStakeDays;
    uint256 internal mininumStakeAmount;
    uint256 internal immutable START_TIME;

    constructor(address managerAddress) ERC20("Long Tail Social Token", "LTST") {

        manager = ISocialTokenManager(managerAddress);

        START_TIME = block.timestamp - 2 hours + 2 minutes - (block.timestamp % 1 days);
        lastInterestAdjustment = type(uint64).max;

        // Pick some default values
        baseInterest        = 334048448267282;
        linearInterest      = 47380335805760;
        quadraticInterest   = -2729560234;
        rewardPerMiningTask = 10**18;
        mininumStakeAmount  = 3125000000000000; // 1/32th of one token
        mininumStakeDays    = 5;
        maximumStakeDays    = 5844; // 16 years
    }

    function setManager(address newManager, bool startInterestAdjustment) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), "Interface unsupported");

        manager = ISocialTokenManager(newManager);
                
        if (startInterestAdjustment)
            lastInterestAdjustment = 0;
    }

    function removeExternalErc20Balance(address tokenContract, address recipient) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Elder);
        require(tokenContract != address(this));

        IERC20(tokenContract).transfer(recipient, IERC20(tokenContract).balanceOf(address(this)));
    }

    function setInterestRates(uint64 base, uint64 linear, int64 quadratic, uint256 miningReward) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(miningReward > 0, INVALID_INPUT); // this would cause a divide by zero error inside the mine function.

        baseInterest = base;
        linearInterest = linear;
        quadraticInterest = quadratic;
        rewardPerMiningTask = miningReward;
    }

    function setContractConstraints(uint256 minStakeAmount, uint64 minStakeDays, uint64 maxStakeDays) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(minStakeDays > 0, INVALID_INPUT); // 0 would mess up mining tasks.

        mininumStakeAmount = minStakeAmount;
        mininumStakeDays = minStakeDays;
        maximumStakeDays = maxStakeDays;
    }

    function stake(uint256 amount, uint256 numberOfDays) public returns(uint32) {
        // cache refrence variables
        uint256 today = getCurrentDay();
        uint256 endDay = today + numberOfDays;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(amount >= mininumStakeAmount, "Stake too small");
        require(amount <= balanceOf(_msgSender()), "Insufficient balance");
        require(numberOfDays <= maximumStakeDays, "Stake too long");
        require(numberOfDays >= mininumStakeDays, "Stake too short");
        require(endDayIndex <= type(uint128).max, STAKE_LIMIT);

        // populate stake data
        while(stakesByAccount[_msgSender()][nextStakeForAccount[_msgSender()]].principal > 0) {
            nextStakeForAccount[_msgSender()] = (nextStakeForAccount[_msgSender()] + 1) % type(uint32).max;
        }
        uint32 accountIndex = uint32(nextStakeForAccount[_msgSender()]);
        nextStakeForAccount[_msgSender()] = (nextStakeForAccount[_msgSender()] + 1) % type(uint32).max;

        stakesByAccount[_msgSender()][accountIndex] = StakeData(
            uint64(today),
            uint64(endDay),
            uint128(endDayIndex),
            amount
        );

        stakesByEndDay[endDay].push(StakeDataPointer(
            _msgSender(),
            calculateInterestRate(_msgSender(), numberOfDays),
            accountIndex
        ));

        // send the stake to this contract
        _transfer(_msgSender(), address(this), amount);

        emit Staked(
            _msgSender(),
            uint64(today),
            uint64(endDay),
            amount,
            stakesByEndDay[endDay][endDayIndex].interestRate,
            accountIndex
        );

        return accountIndex;
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
            if (interest > 0) {
                _mint(stakeAccount, uint256(interest));
            }
        }
        else if (int256(myStake.principal) + interest > 0) {
            _transfer(address(this), stakeAccount, uint256(int256(myStake.principal) + interest));
            _burn(address(this), uint256(-interest));
        }
        else { // exceedingly unlikely... but not impossible
            _burn(address(this), myStake.principal);
        }

        // emit events
        emit RedeemedStake(stakeAccount, uint64(getCurrentDay()), stakeNumber, myStake.principal, interest);
    }

    function mine(uint256 tasksToDo) public virtual {
        require(balanceOf(_msgSender()) > 0, UNAUTHORIZED);

        mining = true;
        uint256 miningReward;
        uint256 interest;
        uint256 today = getCurrentDay();
        uint256 workingDay = lastCompletedDistribution + 1;
        StakeDataPointer storage currentStake;
        StakeData storage accountStake;

        // adjust interest (if needed)
        if (lastInterestAdjustment < today) {
            miningReward = manager.adjustInterest();
            if (miningReward > 0) {
                lastInterestAdjustment = today;
            }
        }

        // reward ended stakes back to accounts
        while (lastCompletedDistribution < today && tasksToDo > 0) {
            while (stakesByEndDay[workingDay].length > 0 && tasksToDo > 0) {
                currentStake = stakesByEndDay[workingDay][stakesByEndDay[workingDay].length - 1];
                if (currentStake.owner != address(0)) {
                    accountStake = stakesByAccount[currentStake.owner][currentStake.index];

                    interest = _fullInterest(accountStake.end - accountStake.start, currentStake.interestRate, accountStake.principal);
                    _transfer(address(this), currentStake.owner, accountStake.principal);
                    if (interest > 0) {
                        _mint(currentStake.owner, interest);
                    }

                    emit RedeemedStake(currentStake.owner, uint64(today), currentStake.index, accountStake.principal, int256(interest));
                    delete(stakesByAccount[currentStake.owner][currentStake.index]);
                    miningReward += rewardPerMiningTask;
                    tasksToDo--;
                }

                stakesByEndDay[workingDay].pop();
            }

            if (stakesByEndDay[workingDay].length == 0) {
                lastCompletedDistribution = workingDay;
                workingDay++;
                miningReward += rewardPerMiningTask / 10;
                tasksToDo--;
            }
        }

        _mint(_msgSender(), miningReward);
        emit AwardToAddress(_msgSender(), uint64(today), "Mining reward", int256(miningReward));

        mining = false;
    }

    function award(address account, int256 amount, string memory explanation) virtual external {
        if (amount == 0) return;
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.AwardableContract);

        if (amount < 0) {
            _burn(account, uint256(-amount));
        }
        else {
            _mint(account, uint256(amount));
        }

        emit AwardToAddress(account, uint64(getCurrentDay()), explanation, amount);
    }

    function getNumMiningTasks() public view returns(uint256 currentTasks, uint256 upcomingTasks) {
        uint256 today = getCurrentDay();
        currentTasks = lastInterestAdjustment < today ? 1 : 0;
        for (uint256 i = lastCompletedDistribution;i <= today;i++) {
            currentTasks = currentTasks + stakesByEndDay[i].length;
        }
        
        upcomingTasks = stakesByEndDay[today + 1].length + (lastInterestAdjustment <= today ? 1 : 0);
    }

    function getContractInterestRates() public view returns(uint64 base, uint64 linear, int64 quadratic, uint256 miningReward) {
        return (
            uint64(baseInterest),
            uint64(linearInterest),
            int64(quadraticInterest),
            rewardPerMiningTask
        );
    }

    function getContractConstraints() public view returns(uint256 minStakeAmount, uint64 minStakeDays, uint64 maxStakeDays) {
        return (mininumStakeAmount, uint64(mininumStakeDays), uint64(maximumStakeDays));
    }

    function getStakeValues (address account, uint32 id) public view returns(uint64 start, uint64 end, uint64 interestRate, uint256 principal) {
        return (
            stakesByAccount[account][id].start,
            stakesByAccount[account][id].end,
            stakesByEndDay[stakesByAccount[account][id].end][stakesByAccount[account][id].index].interestRate,
            stakesByAccount[account][id].principal
        );
    }

    function getCurrentDay() public virtual view returns(uint256 today) {
        today = (block.timestamp - START_TIME) / 1 days;
    }

    function getVotingPower(address account, uint256 minValidStakeLength, uint32[] memory stakeIds) public view returns(uint256 votingPower) {
        StakeData storage thisStake;
        uint256 stakeLength;

        for(uint256 i = 0; i < stakeIds.length; i++) {
            thisStake = stakesByAccount[account][stakeIds[i]];
            stakeLength = thisStake.end - thisStake.start;
            if (thisStake.principal > 0 && stakeLength >= minValidStakeLength) {
                votingPower += (_fullInterest(_votingWeight(thisStake.start, thisStake.end, getCurrentDay()),  
                        stakesByEndDay[thisStake.end][thisStake.index].interestRate, thisStake.principal));
            }
        }
    }

    // This function gets the interest that will be earned if you withdraw a stake on a particular day.
    function calculateInterest(uint256 start, uint256 end, uint256 dayOfWithdrawal, uint256 interestRate, uint256 principal) 
            public pure returns(int256) {
        require(end > start, "Negative stake duration");

        unchecked {
            // Changing your mind on the same day you staked will not incur a penality
            if (dayOfWithdrawal <= start) {
                return 0;
            }

            uint256 full = _fullInterest(end - start, interestRate, principal);

            if (dayOfWithdrawal >= end) {
                return int256(full);
            }
            else {
                return int256(full) - int256(3 * (full * (end - dayOfWithdrawal) / (end - start)));
            }
        }
    }

    function calculateInterestRate(address account, uint256 numberOfDays) public view returns(uint64) {
        // These values should never be set high enough that they *could* overflow. If they do, however, then it's better to rollover than to revert.
        unchecked {
            uint256 interest = (
                baseInterest +
                (linearInterest * numberOfDays) +
                manager.getNftContract().interestBonus(account)
            );

            if (quadraticInterest >= 0) {
                interest += uint256(quadraticInterest) * numberOfDays * numberOfDays;
            }
            else {
                uint256 quadratic = uint256(-quadraticInterest) * numberOfDays * numberOfDays;
                interest = interest > quadratic ? interest - quadratic : 0;
            }

            // cap the value to what can be held in a uint64
            return interest > type(uint64).max ? type(uint64).max : uint64(interest);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (!mining) { manager.authorizeTx(from, to, amount); }
    }

    function _votingWeight(uint256 start, uint256 end, uint256 current) private pure returns(uint256) {
        uint256 totalDays = end - start;
        uint256 daysMature = current - start;

        return daysMature <= totalDays / 2 ? daysMature : (totalDays - daysMature);
    }

    function _fullInterest(uint256 duration, uint256 interestRate, uint256 principal) private pure returns(uint256) {
        return (interestRate * duration * principal) / type(uint64).max;
    }
}
