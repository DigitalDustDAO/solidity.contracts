// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
// import "../SocialToken//ISocialToken.sol";
// import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "./IRule34.sol";

interface IMeasureManager is IERC165 {

    enum Sensitivity {
        Council,
        Elder,
        Token,
        TokenWrapper,
        Rule34
    }

    function authorize(address source, Sensitivity level) external view;
    function getRule34Contract() external view returns(IRule34);
}
