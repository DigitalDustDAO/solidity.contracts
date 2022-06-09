// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenLiquidityPool is IERC165 {
    struct Stake {
        uint64 startDay;
        uint192 principal;
    }


    function setManager(address newManager) external;
    function fundPool(uint256 tokenAmount) external;
    function setInterestRate(uint128 newInterestRate, uint64 newVestingPeriod) external;
    function getStakeData(address account) external view returns(uint192 principal, uint256 uncollectedRewards, uint64 vestingDaysRemaining);
}
