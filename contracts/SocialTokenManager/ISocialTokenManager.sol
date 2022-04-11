// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "../SocialToken//ISocialToken.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";

interface ISocialTokenManager is IERC165 {

    enum Sensitivity {
        Council,
        Maintainance,
        Elder,
        TokenContract,
        AwardableContract
    }

    // public and external views
    function getDaoContract() external view returns(IDigitalDustDAO);
    function getTokenContract() external view returns(ISocialToken);
    function getNftContract() external view returns(ISocialTokenNFT);
    function hasAuxToken(address account) external view returns(bool);

    

    //permission and control
    function authorize(address source, Sensitivity level) external view;
    function authorizeTx(address source, address destination) external view;
    function adjustInterest() external view;
}
