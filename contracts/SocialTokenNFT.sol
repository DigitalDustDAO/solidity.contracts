// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./ISocialTokenNFT.sol";

abstract contract SocialTokenNFT is ISocialTokenNFT {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISocialTokenNFT).interfaceId;
    }
}
