// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ERC777.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "./ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC777 {

    // framerate, interest, adding and redeeming stakes, mining
    struct StakeDataPointer {
        address owner;
        uint64 interestRate;
        uint32 index;
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
    uint private immutable START_TIME;


    mapping(uint256 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;

    //ISocialTokenManager private manager;
    ISocialTokenManager internal manager; // this cannot remain internal

    uint internal lastInterestAdjustment;
    uint private lastCompletedDistribution;
    uint private rewardPerMiningTask;
    uint private miningGasReserve;

    uint private baseInterestRate;
    uint private linearInterestBonus;
    uint private quadraticInterestBonus;

    constructor(address manager_) ERC777("Long Tail Social Token", "LTST") {

        manager = ISocialTokenManager(manager_);

        START_TIME = block.timestamp - (block.timestamp % 1 days);
        lastInterestAdjustment = type(uint64).max;

        // Pick some default values
        baseInterestRate = 50;
        linearInterestBonus = 25;
        quadraticInterestBonus = 10;
        rewardPerMiningTask = 50;
        miningGasReserve = 1500;

        // mint to sender for now
        // TODO: mint to LP
        _mint(_msgSender(), 1000000000000000000000000, "", "");

        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("SocialToken"), address(this));
    }

    function setManager(address newManager, bool startInterestAdjustment) external {
        require(_msgSender() == address(manager));
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId));

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
        require(amount >= MININUM_STAKE_AMOUNT);
        require(balanceOf(stakeAccount) >= amount);
        require(numberOfDays <= MAXIMUM_STAKE_DAYS);
        require(numberOfDays >= MININUM_STAKE_DAYS);
        require(accountIndex <= type(uint32).max);
        require(endDayIndex <= type(uint128).max);

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

        // send 
        _send(stakeAccount, address(this), amount, "", "", false);

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
        uint256 principal = stakesByAccount[stakeAccount][stakeNumber].principal;

        // ensure outputs within range 
        require(principal > 0);
        
        // calculate the reward
        (bool positive, uint256 interest) = calculateInterest(
            stakesByAccount[stakeAccount][stakeNumber].start,
            stakesByAccount[stakeAccount][stakeNumber].end,
            stakesByEndDay[stakesByAccount[stakeAccount][stakeNumber].end][stakesByAccount[stakeAccount][stakeNumber].index].interestRate,
            stakesByAccount[stakeAccount][stakeNumber].principal
        );

        // delete the stake data
        delete(stakesByEndDay[stakesByAccount[stakeAccount][stakeNumber].end][stakesByAccount[stakeAccount][stakeNumber].index]);
        delete(stakesByAccount[stakeAccount][stakeNumber]);

        // distribute the funds
        if (positive) {
            _send(address(this), stakeAccount, principal, "", "", false);
            _mint(stakeAccount, interest, "", "", false);
        }
        else {
            _send(address(this), stakeAccount, principal - interest, "", "", false);
            _burn(address(this), interest, "", "");
        }

        // emit events
        unchecked { // overflow is very remotely possible here, but should not cause the function to revert since this is not essential functionality
            emit RedeemedStake(stakeAccount, principal, positive ? int256(interest) : (int256(interest) * -1));
        } 
    }

    function mine() public virtual {
        require(balanceOf(_msgSender()) > 0);

        uint256 tasksCompleted = 0;
        uint256 interest;
        StakeDataPointer memory currentStake;
        StakeData memory accountStake;

        // adjust interest (if needed)
        if (lastInterestAdjustment < getCurrentDay()) {
            manager.adjustInterest();
            tasksCompleted++;
        }

        // reward ended stakes to people
        for (uint256 i = lastCompletedDistribution;i <= getCurrentDay();i++) {
            while (stakesByEndDay[i].length > 0 && gasleft() >= miningGasReserve) {
                currentStake = stakesByEndDay[i][stakesByEndDay[i].length - 1];
                stakesByEndDay[i].pop();
                if (currentStake.owner != address(0)) {
                    accountStake = stakesByAccount[currentStake.owner][currentStake.index];
                    delete(stakesByAccount[currentStake.owner][currentStake.index]);

                    // done this way to prevent the possibility of rollbacks.
                    interest = _fullInterest(accountStake.end - accountStake.start, currentStake.interestRate, accountStake.principal);
                    _move(address(this), address(this), currentStake.owner, accountStake.principal, "", "");
                    _mint(currentStake.owner, interest, "", "", true);

                    tasksCompleted++;
                }
            }
        }

        if (tasksCompleted > 0) {
            // TODO: send pool tokens if available
            _mint(_msgSender(), rewardPerMiningTask * tasksCompleted, "", "", true);
            emit MiningReward(_msgSender(), uint64(tasksCompleted), rewardPerMiningTask * tasksCompleted);
        }
    }

    function award(address account, int256 amount) virtual external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.AwardableContract);

        if (amount < 0) {
            _burn(account, uint256(-amount), "", "");
        }
        else if (amount > 0) {
            _mint(account, uint256(amount), "", "", false);
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
        StakeData memory thisStake;
        uint256 finalDepth = stakesByAccount[account].length <= 256 ? 0 : stakesByAccount[account].length - 256;

        for(uint256 i = stakesByAccount[account].length - 1; i > finalDepth; i--) {
            thisStake = stakesByAccount[account][i];
            if (thisStake.principal > 0) {
                votingPower += (_votingWeight(thisStake.start, thisStake.end, getCurrentDay()) 
                    * _fullInterest(thisStake.start - thisStake.end,  stakesByEndDay[thisStake.end][thisStake.index].interestRate, thisStake.principal));
            }
        }

        return votingPower;
    }

    function calculateInterest(uint256 start, uint256 end, uint256 interestRate, uint256 principal) public view returns(bool, uint256) {
        uint256 halfStakeLength = (end - start) / 2;
        uint256 timeStaked = getCurrentDay() - start;
        uint256 payoff = _fullInterest(end - start, interestRate, principal);
        if (timeStaked < halfStakeLength) {
            return (false, (payoff * timeStaked) / halfStakeLength);
        }
        else {
            return (true, (payoff * (timeStaked - halfStakeLength)) / halfStakeLength);
        }
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

    // function _beforeTokenTransfer(address operator, address from, address to, uint256 amount) internal view override {
    //     if (to != address(0) && to != address(this)) {
    //         manager.authorize(to, ISocialTokenManager.Sensitivity.Basic);
    //     }
    // }

    function send(address recipient, uint256 amount, bytes memory data) public virtual override {
        manager.authorize(recipient, ISocialTokenManager.Sensitivity.Basic);
        super.send(recipient, amount, data);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        manager.authorize(recipient, ISocialTokenManager.Sensitivity.Basic);
        return super.transfer(recipient, amount);
    }
}