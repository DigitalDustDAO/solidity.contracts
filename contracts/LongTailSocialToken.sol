// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "./ISocialToken.sol";

contract LongTailSocialToken is ISocialToken, ERC777 {

// framerate, interest, adding and redeeming stakes, mining
    struct StakeData {
        address owner;
        uint32 start;
        uint32 end;
        uint32 apr;
        uint256 principal;
        uint256 id;
   }

    //uint constant STAKE_ARRAY_SIZE = 5872;
    uint private constant MAXIMUM_STAKE_DAYS = 5840;
    //uint constant MAXIMUM_STAKES_PER_ADDRESS = uint24.max;

    mapping(uint32 => StakeData[]) private stakesByEndDay;
    mapping(address => StakeData[]) private stakesByAccount;
    //mapping(uint256 => StakeData) private stakeList;

    //uint128 public nextStakeId;

    uint private START_TIME;
    uint private TIME_PER_DAY;

    constructor(address manager)  {

    }

    function stake(uint256 principal, uint32 numberOfDays) public returns(uint256) {
        
    }

    function getUserStakes (uint startIndex, uint number) public view returns(StakeData[]) {

    }

    function _currentFrame() private virtual returns(uint32) {
        
    }
}