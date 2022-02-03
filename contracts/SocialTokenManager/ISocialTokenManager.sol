// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenManager is IERC165 {

    enum Sensitivity {
        Basic,
        Council,
        Maintainance,
        Elder,
        TokenContract,
        NFTContract,
        Manager
    }

    function getDaoContract() external view returns(IDigitalDustDAO);
    function getTokenContract() external view returns(ISocialToken);
    function getNftContract() external view returns(ISocialTokenNFT);

    function authorize(address source, address target, Sensitivity level) external view;
    function authorize(address source, Sensitivity level) external view;
    function adjustInterest() external view;
}