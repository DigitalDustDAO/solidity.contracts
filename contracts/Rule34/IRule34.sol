// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IRule34 is IERC165 {
    
    event RewardIssued (
        address indexed recipiant,
        int128 tokensRewarded,
        uint128 NFTsRewarded
    );

    function setManager(address newManager) external;
    function getTokenUri(address account, address nftContract) external view returns(string memory);
}