// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISocialToken {
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

    event MiningReward (
        address indexed account,
        uint64 tasksCompleted,
        uint256 reward
    );

    event AwardToAddress (
        address indexed account,
        int256 amount,
        bytes explination
    );

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

    function setManager(address newManager, bool startInterestAdjustment) external;
    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint64 miningReward, uint64 miningReserve) external;
    function award(address account, int256 amount, bytes memory explanation) external;
}