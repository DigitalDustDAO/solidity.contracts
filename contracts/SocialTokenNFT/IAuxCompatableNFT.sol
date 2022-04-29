// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAuxCompatableNFT {
    function tokenAuxURI(uint256 tokenId, bytes memory signedMessage) external view returns(bool different, string memory uri);
    function hasAuxURI(uint256 tokenId) external view returns(bool auxURIExists);
}
