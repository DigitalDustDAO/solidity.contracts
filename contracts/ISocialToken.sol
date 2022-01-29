// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

interface ISocialToken is IERC165 {
    event Staked (
        address indexed account,
        uint64 indexed duration,
        uint64 indexed endDay,
        uint256 amount,
        uint32 interestRate,
        uint64 id
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

    function setManager(address newManager, bool startInterestAdjustment) external;
    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint64 miningReward) external;
    function forgingExpense(address account, int256 amount) external;
}