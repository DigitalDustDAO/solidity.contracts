// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "./ILongTailManager.sol";
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

    uint private START_TIME;
    uint private TIME_PER_DAY;

    ILongTailManager private manager;

    constructor(address memory manager_, address[] memory defaultOperators_) ERC777("Long Tail Social Token", "LTST", defaultOperators_) {
        manager = ILongTailManager(manager_);
    }

    function changeManager(address newManager) public {
        require(_msgSender() == manager, "Not for users");
        manager = ILongTailManager(newManager);
    }

    function stake(uint256 amount, uint32 numberOfDays) public returns(uint256) {
        require(_balance[_msgSender()] >= amount, "Insufficient balance");
    }

    ////
    // Returns up to 12 stakes for the supplied user starting at the supplied index.
    ////
    function getUserStakes (address account, uint startIndex) public view returns(StakeData[]) {
        
    }

    function _currentFrame() private virtual returns(uint32) {
        
    }
}