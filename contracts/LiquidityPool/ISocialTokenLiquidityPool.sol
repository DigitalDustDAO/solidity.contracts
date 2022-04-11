// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenLiquidityPool is IERC165 {

    function setManager(address newManager) external;
}
