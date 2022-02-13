// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISocialTokenNFT is IERC165 {
    
    event RewardIssued (
        address indexed recipiant,
        int128 tokensRewarded,
        uint128 NFTsRewarded
    );

    function interestBonus(address account) external view returns(uint64);
    function setManager(address newManager) external;
}