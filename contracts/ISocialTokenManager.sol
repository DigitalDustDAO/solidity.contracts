// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISocialTokenManager is IERC165 {

    function setTokenManager(address addr) external returns (address);
    // function setTokenApr(uint32 apr) external returns (uint32);  // TODO: implement in LTST first

    function setNFT(address addr) external returns (address);
    // function setNftApr(uint32 apr) external returns (uint32);  // TODO: implement in LTST first

    function authorize(address source, address target, uint8 level) external view returns(bool);
    function adjustInterest() external;
}