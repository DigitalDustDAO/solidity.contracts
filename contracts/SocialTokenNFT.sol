// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./ISocialTokenNFT.sol";

abstract contract SocialTokenNFT is ISocialTokenNFT, ERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenNFT).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
