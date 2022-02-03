// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

//import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

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

    function setManager(address newManager, bool startInterestAdjustment) external;
    function setInterestRates(uint64 base, uint64 linear, uint64 quadratic, uint64 miningReward, uint64 miningReserve) external;
    function forge(address account, int256 amount) external;
}