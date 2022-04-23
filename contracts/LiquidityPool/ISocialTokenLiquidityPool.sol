// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenLiquidityPool is IERC165 {

    struct Stake {
        uint32 startDay;
        uint64 interestRate;
        uint160 principal;
    }


    function setManager(address newManager) external;
    function fundPool(uint256 tokenAmount) external;
    function setInterestRate(uint64 newDailyInterestRate) external;
    function getStakeData(address account) external view returns(uint160 principal, uint256 uncollectedRewards);
}
