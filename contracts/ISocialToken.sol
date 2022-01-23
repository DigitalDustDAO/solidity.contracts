// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISocialToken {
    event Staked (
        address indexed account,
        uint16 indexed duration,
        uint64 indexed endDay,
        uint256 amount,
        uint32 interestRate,
        uint96 id
    );

    event RedeemedStake (
        address indexed account,
        uint256 principal,
        int256 interest
    );
}