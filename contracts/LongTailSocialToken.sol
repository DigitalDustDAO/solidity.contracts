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
        uint96 index;
   }

    struct StakeData {
        uint64 start;
        uint64 end;
        uint32 interest;
        uint96 index;
        uint256 principal;
    }

    //uint constant STAKE_ARRAY_SIZE = 5872;
    uint private constant MAXIMUM_STAKE_DAYS = 5840;
    uint private constant MININUM_STAKE_DAYS = 30;
    //uint constant MAXIMUM_STAKES_PER_ADDRESS = uint24.max;

    mapping(uint64 => StakeDataPointer[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;
    //mapping(uint256 => StakeData) private stakeList;

    uint private START_TIME;
    uint private TIME_PER_DAY;

    ISocialTokenManager private manager;
    ISocialTokenNFT private nftContract;


    constructor(address manager_, address[] memory defaultOperators_) 
        ERC777("Long Tail Social Token", "LTST", defaultOperators_) {

        manager = ISocialTokenManager(manager_);
    }

    function setManager(address newManager) public {
        require(_msgSender() == address(manager), "Not for users");

        manager = ISocialTokenManager(newManager);
    }

    function setNFT(address newNFT) public {
        require(_msgSender() == address(manager), "Not for users");

        nftContract = ISocialTokenNFT(newNFT);
    }

    function stake(uint256 amount, uint64 numberOfDays) public returns(uint256) {
        // cache refrence variables
        address stakeAccount = _msgSender();
        uint64 currentDay = _currentDay();
        uint64 endDay = currentDay + numberOfDays;
        uint256 accountIndex = stakesByAccount[stakeAccount].length;
        uint256 endDayIndex = stakesByEndDay[endDay].length;

        // ensure inputs are not out of range 
        require(balanceOf(stakeAccount) >= amount, "Insufficient balance");
        require(numberOfDays <= MAXIMUM_STAKE_DAYS, "Stake duration is too long"); 
        require(numberOfDays >= MININUM_STAKE_DAYS, "Stake was too short");
        require(accountIndex <= type(uint96).max, "This address may no longer stake");
        require(endDayIndex <= type(uint96).max, "Too many stakes are ending on that day");

        //populate stake data
        stakesByEndDay[endDay].push(StakeDataPointer(
            stakeAccount,
            uint96(accountIndex)
        ));

        stakesByAccount[stakeAccount].push(StakeData(
            currentDay, 
            endDay,
            _calculateInterest(numberOfDays), 
            uint96(endDayIndex),
            amount
        ));

        // send 
        _send(stakeAccount, address(this), amount, "", "staked", false);

        //TODO: emit event

        return accountIndex;
    }

    function unstake(uint256 stakeNumber) public {
        
    }

    function getStakeStart (address account, uint id) public view returns(uint64) {
        return stakesByAccount[account][id].start;
    }

    function getStakeEnd (address account, uint id) public view returns(uint64) {
        return stakesByAccount[account][id].end;
    }

    function getStakeInterest (address account, uint id) public view returns(uint32) {
        return stakesByAccount[account][id].interest;
    }

    function getStakePrincipal (address account, uint id) public view returns(uint256) {
        return stakesByAccount[account][id].principal;
    }

    function _currentDay() private returns(uint32) {
        
    }

    function _calculateInterest(uint64 numberOfDays) private returns(uint32) {
        
    }
}