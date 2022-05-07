// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISocialToken {

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
    
    event Staked (
        address indexed account,
        uint64 indexed duration,
        uint64 indexed endDay,
        uint256 amount,
        uint64 interestRate,
        uint32 id
    );

    event RedeemedStake (
        address indexed account,
        uint256 principal,
        int256 interest
    );

    event AwardToAddress (
        address indexed account,
        int256 amount,
        string explination
    );

    function setManager(address newManager, bool startInterestAdjustment) external;
    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint256 miningReward, uint256 miningReserve) external;
    function setContractConstraints(uint256 minStakeAmount, uint64 minStakeDays, uint64 maxStakeDays) external;
    function award(address account, int256 amount, string memory explanation) external;
    function getVotingPower(address account, uint64 minValidStakeLength, uint32[] memory stakeIds) external view returns(uint256 votingPower);
    function getNumMiningTasks() external view returns(uint256 currentTasks, uint256 upcomingTasks);
    function calculateInterest(uint256 start, uint256 end, uint256 dayOfWithdrawal, uint256 interestRate, uint256 principal) 
        external pure returns(int256 interest);
}
