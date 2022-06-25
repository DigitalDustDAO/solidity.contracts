// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPrivateAdultNFT {
    function adultURI(uint256 tokenId, bytes memory signedMessage) external view returns(bool isDifferent, string memory uri);
}
