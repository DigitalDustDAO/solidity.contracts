// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

abstract contract SocialTokenNFT is ISocialTokenNFT, ERC721 {

    ISocialTokenManager private manager;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenNFT).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function interestBonus(address account) external view returns(uint64) {
        return 0;
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager));
        manager = ISocialTokenManager(newManager);
    }
}