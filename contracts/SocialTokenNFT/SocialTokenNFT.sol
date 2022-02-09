// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialNFT is ISocialTokenNFT, ERC721 {

    ISocialTokenManager internal manager;

    string public baseTokenURI;

    struct NFTData {
        uint16 level;
        uint32 group;
        uint128 index;
    }

    constructor(address manager_) ERC721("Long Tail Social NFT", "LTSNFT") {
        manager = ISocialTokenManager(manager_);
    }

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

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory newURI) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        baseTokenURI = newURI;
    }

    function forge(uint256 quantity) external {}
}
