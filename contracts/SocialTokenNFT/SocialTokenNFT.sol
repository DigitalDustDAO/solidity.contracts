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
        uint64 level;
        uint64 group;
        uint128 index;
    }

    uint private constant MAXIMUM_LEVEL = 8;

    mapping(uint256 => NFTData) private dataMap;
    mapping(address => uint256[MAXIMUM_LEVEL]) private levelBalances;

    uint128[MAXIMUM_LEVEL][] private definedGroups;
    uint128[MAXIMUM_LEVEL][] private nextIndex;
    uint128 private elementSize;
    uint128 private nextElementIndex;
    uint256 private nextTokenId;
    uint256 private maximumElementMint;
    uint256 private elementMintCost;
    uint64[MAXIMUM_LEVEL] private interestBonuses;

    constructor(address manager_) ERC721("Long Tail Social NFT", "LTSNFT") {
        manager = ISocialTokenManager(manager_);

        interestBonuses[0] = 32768;
        for(uint256 i = 1;i < MAXIMUM_LEVEL;i++) {
            interestBonuses[i] = interestBonuses[i - 1] * 2;
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenNFT).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function setInterestBonus(uint256 level, uint64 newBonus) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Elder);
        require(level <= MAXIMUM_LEVEL);

        interestBonuses[level] = newBonus;
    }

    function interestBonus(address account) external view returns(uint64) {
        int256 maxLevel = int(MAXIMUM_LEVEL);
        unchecked {
            while(maxLevel >= 0 && levelBalances[account][uint256(maxLevel)] == 0) {
                maxLevel--;
            }

            return maxLevel >= 0 ? interestBonuses[uint256(maxLevel)] : 0;
        }
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

    function setElementForgeValues(uint256 newMax, uint256 newCost) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        maximumElementMint = newMax;
        elementMintCost = newCost;
    }

    function forgeElements() public {
        forgeElements(1);
    }

    function forgeElements(uint256 quantity) public {
        require(quantity <= maximumElementMint);
        require(quantity > 0);

        manager.getTokenContract().forge(_msgSender(), int256(quantity * elementMintCost));

        for (uint256 i = 0;i < quantity;i++) {

            _safeMint(_msgSender(), nextTokenId);
            dataMap[nextTokenId] = NFTData (0, 0, nextElementIndex);
            levelBalances[_msgSender()][0]++;

            nextElementIndex = (nextElementIndex + 1) % elementSize;
        }
    }

    //TODO: forge

    function resizeLibarary(uint64 group, uint128[] memory sizes) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        // Expand the array (if nessessary)
        // TODO: Need to check if I'm using arrays correctly here
        for (uint256 i = 0;i < sizes.length;i++) {
            while (definedGroups[i].length < group ) {
                definedGroups.push([0]);
            }

            definedGroups[i][group] = sizes[i];
        }
    }

    function resizeElementLibarary(uint128 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        elementSize = size;
        if (nextElementIndex > size) {
            nextElementIndex = 0;
        }
    }

    function getGroupSizes(uint64 group) public view returns(uint128[MAXIMUM_LEVEL] memory) {
        uint128[MAXIMUM_LEVEL] memory sizes;
        uint256 size = 0;
        while (definedGroups[size].length >= group && size < MAXIMUM_LEVEL) {
            size++;
        }

        for (uint256 i = 0;i < size;i++) {
            sizes[i] = definedGroups[i][group];
        }

        return sizes;
    }
}
