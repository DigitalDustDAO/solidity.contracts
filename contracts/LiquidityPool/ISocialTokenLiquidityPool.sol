// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenLiquidityPool is IERC165 {

    struct Stake {
        uint32 startDay;
        uint96 interestRate;
        uint128 principal;
    }


    function setManager(address newManager) external;
    function fundPool(uint256 tokenAmount) external;
    function setInterestRate(uint96 newInterestRate, uint32 newVestingPeriod) external;
    function getStakeData(address account) external view returns(uint128 principal, uint96 mininumInterestRate, uint256 uncollectedRewards);
}
