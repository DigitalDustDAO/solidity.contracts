// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

//import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISocialTokenNFT {
    
    event RewardIssued (
        address indexed recipiant,
        uint128 tokensRewarded,
        uint128 NFTsRewarded
    );

    function setManager(address newManager) external;
    function interestBonus(address account) external view returns(uint64);
    function setForgeValues(uint256 newMax, uint256 newElementCost, uint256 newForgeCost, uint256 rewardPerBounty) external;
}