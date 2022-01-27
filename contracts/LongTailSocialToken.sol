// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "./ISocialTokenManager.sol";
import "./ISocialTokenNFT.sol";
import "./ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC777 {

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
    //mapping(uint256 => StakeData) private stakeList;

    uint256 private START_TIME;

    uint64 private baseInterestRate;
    uint64 private linearInterestBonus;
    uint64 private quadraticInterestBonus;


    ISocialTokenManager private manager;
    ISocialTokenNFT private nftContract;

    modifier onlyManager() {
        require(_msgSender() == address(manager), "Not for users");
        _;
    }

    constructor(address manager_, address[] memory defaultOperators_) 
        ERC777("Long Tail Social Token", "LTST", defaultOperators_) {

        manager = ISocialTokenManager(manager_);

        START_TIME = block.timestamp - (block.timestamp % 1 days);
    }

    function setManager(address newManager) public onlyManager {
        manager = ISocialTokenManager(newManager);
    }

    function setNFT(address newNFT) public onlyManager {
        nftContract = ISocialTokenNFT(newNFT);
    }

    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic) public onlyManager {
        if (base > 0) {
            baseInterestRate = base;
        }

        if (linear > 0) {
            linearInterestBonus = linear;
        }

        if (quadratic > 0) {
            quadraticInterestBonus = quadratic;
        }
    }

    function stake(uint256 amount, uint16 numberOfDays) public returns(uint64) {
        // cache refrence variables
        address stakeAccount = _msgSender();
        uint64 currentDay = _currentDay();
        uint64 endDay = currentDay + numberOfDays;
        uint256 accountIndex = stakesByAccount[stakeAccount].length;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(amount >= MININUM_STAKE_AMOUNT, "Amount of stake too low");
        require(balanceOf(stakeAccount) >= amount, "Insufficient balance");
        require(numberOfDays <= MAXIMUM_STAKE_DAYS, "Stake duration is too long"); 
        require(numberOfDays >= MININUM_STAKE_DAYS, "Stake duration is too short");
        require(accountIndex <= type(uint64).max, "Maximum number of stakes reached for this address");
        require(endDayIndex <= type(uint128).max, "Too many stakes are ending on that day");

        // populate stake data
        stakesByEndDay[endDay].push(StakeDataPointer(
            stakeAccount,
            _calculateInterestRate(stakeAccount, numberOfDays),
            uint64(accountIndex)
        ));

        stakesByAccount[stakeAccount].push(StakeData(
            currentDay, 
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
        require(principal > 0, "Stake does not exist or has already been redeemed");
        
        // calculate the reward
        (bool positive, uint256 interest) = _calculateInterest(
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
            _mint(stakeAccount, interest, "", "staking reward");
        }
        else {
            _send(address(this), stakeAccount, principal - interest, "", "", true);
            _burn(address(this), interest, "", "penality for early withdrawal");
        }

        // emit events
        unchecked { // overflow is theoritically possible here, but should not cause the function to revert
            emit RedeemedStake(stakeAccount, principal, positive ? int256(interest) : (int256(interest) * -1));
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

    function _currentDay() private view returns(uint64) {
        return uint64((block.timestamp - START_TIME) / 1 days);
    }

    function _calculateInterest(uint64 start, uint64 end, uint32 interestRate, uint256 principal) private view returns(bool, uint256) {
        uint64 halfStakeLength = (end - start) / 2;
        uint64 timeStaked = _currentDay() - start;
        uint256 payoff = (interestRate * halfStakeLength * 2 * principal) / type(uint32).max;
        if (timeStaked < halfStakeLength) {
            return (false, (payoff * timeStaked) / halfStakeLength);
        }
        else {
            return (true, (payoff * (timeStaked - halfStakeLength)) / halfStakeLength);
        }
    }

    function _calculateInterestRate(address account, uint64 numberOfDays) private returns(uint32) {
        uint256 interest = baseInterestRate + uint256(linearInterestBonus * numberOfDays) + uint256(quadraticInterestBonus * numberOfDays * numberOfDays) + uint256(nftContract.interestBonus(account));
        // cap the value at what can be held in a uint64 and downcast it into a uint32
        return interest > type(uint64).max ? type(uint32).max : uint32(interest / type(uint32).max);
    }
}