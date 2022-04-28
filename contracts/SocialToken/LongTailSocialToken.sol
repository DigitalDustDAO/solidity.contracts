// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC20 {

    uint256 public constant MAXIMUM_STAKE_DAYS = 5844;
    uint256 public constant MININUM_STAKE_DAYS = 14;
    uint256 private constant MININUM_STAKE_AMOUNT = 1000000000000; // = 0.0000001 token
    uint256 public immutable START_TIME;

    string private constant STAKE_LIMIT = "Stake limit reached";
    string private constant UNAUTHORIZED = "Not authorized";

    mapping(uint256 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;

    ISocialTokenManager public manager;

    bool private mining;
    uint256 internal lastInterestAdjustment;
    uint256 internal lastCompletedDistribution;
    uint256 internal rewardPerMiningTask;
    uint256 internal miningGasReserve;
    uint256 internal baseInterestRate;
    uint256 internal linearInterestBonus;
    uint256 internal quadraticInterestBonus;

    constructor(address manager_) ERC20("Long Tail Social Token", "LTST") {

        manager = ISocialTokenManager(manager_);

        START_TIME = block.timestamp - (block.timestamp % 1 days);
        lastInterestAdjustment = type(uint64).max;

        // Pick some very low default values
        baseInterestRate = 50000000;
        linearInterestBonus = 25000000;
        quadraticInterestBonus = 10000000;
        rewardPerMiningTask = 10**18;
        miningGasReserve = 1500;
    }

    function setManager(address newManager, bool startInterestAdjustment) external {
        require(_msgSender() == address(manager), UNAUTHORIZED);
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId), "Interface unsupported");

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

    function stake(uint256 amount, uint16 numberOfDays) public returns(uint32) {
        // cache refrence variables
        address stakeAccount = _msgSender();
        uint256 today = getCurrentDay();
        uint256 endDay = today + numberOfDays;
        uint256 accountIndex = stakesByAccount[stakeAccount].length;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(amount >= MININUM_STAKE_AMOUNT, "Stake too small");
        require(balanceOf(stakeAccount) >= amount, "Insufficient balance");
        require(numberOfDays <= MAXIMUM_STAKE_DAYS, "Stake too long");
        require(numberOfDays >= MININUM_STAKE_DAYS, "Stake too short");
        require(accountIndex <= type(uint32).max, STAKE_LIMIT);
        require(endDayIndex <= type(uint128).max, STAKE_LIMIT);

        // reduce the amount 

        // populate stake data
        stakesByEndDay[endDay].push(StakeDataPointer(
            stakeAccount,
            calculateInterestRate(stakeAccount, numberOfDays),
            uint32(accountIndex)
        ));

        stakesByAccount[stakeAccount].push(StakeData(
            uint64(today),
            uint64(endDay),
            uint128(endDayIndex),
            amount
        ));

        // send the stake to this contract
        _transfer(stakeAccount, address(this), amount);

        emit Staked(
            stakeAccount,
            numberOfDays,
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
        StakeData storage myStake = stakesByAccount[stakeAccount][stakeNumber];

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
        uint256 tasksCompleted = 0;
        uint256 interest;
        StakeDataPointer storage currentStake;
        StakeData storage accountStake;

        // adjust interest (if needed)
        if (lastInterestAdjustment < getCurrentDay()) {
            manager.adjustInterest();
            tasksCompleted++;
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

    function getNumMiningTasks() public virtual view returns(uint256) {
        uint256 today = getCurrentDay();
        uint256 numTasks = lastInterestAdjustment < today ? 1 : 0;
        for (uint256 i = lastCompletedDistribution;i <= today;i++) {
            numTasks = numTasks + stakesByEndDay[i].length;
        }
        return numTasks;
    }

    function getContractInterestRates() public virtual view returns(uint64, uint64, uint64, uint64, uint64) {
        return (
            uint64(baseInterestRate),
            uint64(linearInterestBonus),
            uint64(quadraticInterestBonus),
            uint64(rewardPerMiningTask),
            uint64(miningGasReserve)
        );
    }


    function getStakeValues (address account, uint32 id) public virtual view returns(uint64, uint64, uint64, uint256) {
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

    // Need to test how much gas this function uses.
    function getVotingPower(address account) external view returns(uint256) {
        uint256 votingPower = 0;
        StakeData storage thisStake;
        uint256 finalDepth = stakesByAccount[account].length <= 128 ? 0 : stakesByAccount[account].length - 128;

        for(uint256 i = stakesByAccount[account].length - 1; i > finalDepth; i--) {
            thisStake = stakesByAccount[account][i];
            if (thisStake.principal > 0) {
                votingPower += (_votingWeight(thisStake.start, thisStake.end, getCurrentDay()) 
                    * _fullInterest(thisStake.start - thisStake.end,  stakesByEndDay[thisStake.end][thisStake.index].interestRate, thisStake.principal));
            }
        }

        return votingPower;
    }

    // This function gets the interest that will be earned if you withdraw a stake on a particular day.
    //  If you withdraw the same day you stake then you don't get any penality.
    function calculateInterest(uint256 start, uint256 end, uint256 dayOfWithdrawal, uint256 interestRate, uint256 principal) 
            public pure returns(int256 interest) {
        uint256 halfStakeLength = (end - start) / 2;
        uint256 timeStaked = dayOfWithdrawal - start;

        if (timeStaked == 0) {
            interest = 0;
        }
        else if (timeStaked < halfStakeLength) {
            interest = int256((_fullInterest(end - start, interestRate, principal) * timeStaked) / halfStakeLength) * -1;
        }
        else {
            interest = int256((_fullInterest(end - start, interestRate, principal) * (timeStaked - halfStakeLength)) / halfStakeLength);
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
            // cap the value at what can be held in a uint64 and downcast it into a uint32
            return interest > type(uint64).max ? type(uint64).max : uint64(interest);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (!mining) { manager.authorizeTx(from, to, amount); }
    }

    function _votingWeight(uint256 start, uint256 end, uint256 currentDay) private pure returns(uint256){
        if (currentDay - start <= (end - start) / 2) {
            return (currentDay - start) * 2;
        }
        else {
            return ((end - start) - (currentDay - start)) * 2;
        }
    }

    function _fullInterest(uint256 duration, uint256 interestRate, uint256 principal) private pure returns(uint256) {
        return (interestRate * duration * principal) / type(uint64).max;
    }
}
