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
        uint64 indexed startDay,
        uint64 indexed endDay,
        uint256 amount,
        uint64 interestRate,
        uint32 id
    );

    event RedeemedStake (
        address indexed account,
        uint64 indexed redeemedDay,
        uint32 indexed id,
        uint256 principal,
        int256 payment
    );

    event AwardToAddress (
        address indexed account,
        uint64 indexed dayIssued,
        string explanation,
        int256 amount
    );

    function setManager(address newManager, bool startInterestAdjustment) external;
    function setInterestRates(uint64 base, uint64 linear, int64 quadratic, uint256 miningReward) external;
    function setContractConstraints(uint256 minStakeAmount, uint64 minStakeDays, uint64 maxStakeDays) external;
    function award(address account, int256 amount, string memory explanation) external;
    function getVotingPower(address account, uint256 minValidStakeLength, uint32[] memory stakeIds) external view returns(uint256 votingPower);
    function getNumMiningTasks() external view returns(uint256 currentTasks, uint256 upcomingTasks);
    function calculateInterest(uint256 start, uint256 end, uint256 dayOfWithdrawal, uint256 interestRate, uint256 principal) 
        external pure returns(int256 interest);
}
