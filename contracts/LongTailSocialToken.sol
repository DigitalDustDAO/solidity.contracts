// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "./ISocialTokenManager.sol";
import "./ISocialTokenNFT.sol";
import "./ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC777 {

// framerate, interest, adding and redeeming stakes, mining
    struct StakeDataEnd {
        address owner;
        uint32 start;
        uint64 interest;
        uint256 principal;
        uint256 index;
   }

    struct StakeDataAccount {
        uint32 start;
        uint32 end;
        uint64 interest;
        uint256 principal;
        uint256 index;
   }

    //uint constant STAKE_ARRAY_SIZE = 5872;
    uint private constant MAXIMUM_STAKE_DAYS = 5840;
    //uint constant MAXIMUM_STAKES_PER_ADDRESS = uint24.max;

    mapping(uint32 => StakeDataEnd[]) private stakesByEndDay;
    mapping(address => StakeDataAccount[]) private stakesByAccount;
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

    function stake(uint256 amount, uint32 numberOfDays) public returns(uint256) {
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");
        require(numberOfDays <= MAXIMUM_STAKE_DAYS && _currentFrame() + numberOfDays <= type(uint32).max, "Stake was too long");
        require(numberOfDays > 0, "Must stake for at least 1 day");

        uint32 currentFrame = _currentFrame();
        uint32 endDay = currentFrame + numberOfDays;
        uint64 interest = _calculateInterest(numberOfDays);

        stakesByEndDay[endDay].push(StakeDataEnd(
            _msgSender(),
            currentFrame, 
            interest, 
            amount,
            stakesByAccount[_msgSender()].length
        ));

        stakesByAccount[_msgSender()].push(StakeDataAccount(
            currentFrame, 
            endDay,
            interest, 
            amount,
            stakesByEndDay[endDay].length - 1
        ));

        _send(_msgSender(), address(this), amount, "", "staked", false);

        //TODO: emit event

        return stakesByAccount[_msgSender()].length - 1;
    }

    function unstake(uint256 stakeNumber) public {

    }

    function getStakeStart (address account, uint id) public view returns(uint32) {
        return stakesByAccount[account][id].start;
    }

    function getStakeEnd (address account, uint id) public view returns(uint32) {
        return stakesByAccount[account][id].end;
    }

    function getStakeInterest (address account, uint id) public view returns(uint64) {
        return stakesByAccount[account][id].interest;
    }

    function getStakePrincipal (address account, uint id) public view returns(uint256) {
        return stakesByAccount[account][id].principal;
    }

    function _currentFrame() private returns(uint32) {
        
    }

    function _calculateInterest(uint32 numberOfDays) private returns(uint64) {
        
    }
}