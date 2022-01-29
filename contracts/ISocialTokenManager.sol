// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./ISocialToken.sol";
import "./ISocialTokenNFT.sol";

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

    function setTokenManager(address addr) external returns (address);
    // function setTokenApr(uint32 apr) external returns (uint32);  // TODO: implement in LTST first

    function setNFT(address addr) external returns (address);
    // function setNftApr(uint32 apr) external returns (uint32);  // TODO: implement in LTST first

    function getTokenContract() external view returns(ISocialToken);
    function getNftContract() external view returns(ISocialTokenNFT);

    function authorize(address source, address target, Sensitivity level) external view;
    function authorize(address source, Sensitivity level) external view;
    function adjustInterest() external view;
}