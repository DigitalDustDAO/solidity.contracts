// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPublicAdultNFT {
    function adultURI(uint256 tokenId) external view returns(bool isDifferent, string memory uri);
}
