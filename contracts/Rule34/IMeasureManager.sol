// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface IMeasureManager is IERC165 {

    enum Sensitivity {
        Council,
        Elder,
        TokenWrapper,
        Rule34
    }

    function authorize(address source, Sensitivity level) external view;
}
