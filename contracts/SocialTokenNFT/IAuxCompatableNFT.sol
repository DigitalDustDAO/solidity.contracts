// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAuxCompatableNFT {
    function iconURL(uint256 uriIndex) external view returns(string memory url);
    function tokenAuxURI(uint256 tokenId, uint256 uriIndex, bytes memory signedMessage) external view returns(string memory uri);
    function hasAuxURI(uint256 tokenId, uint256 uriIndex) external view returns(bool auxURIExists);
}
