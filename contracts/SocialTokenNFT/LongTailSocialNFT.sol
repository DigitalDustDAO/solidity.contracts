// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialNFT is ISocialTokenNFT, ERC721 {
    using Strings for uint64;
    using Strings for uint128;

    ISocialTokenManager internal manager;

    string public baseTokenURI;

    struct NFTData {
        uint64 level;
        uint64 group;
        uint128 index;
    }

    struct GroupPointer {
        uint128 size;
        uint128 nextIndex;
    }

    uint private constant MAXIMUM_LEVEL = 8;

    mapping(uint256 => NFTData) private dataMap;
    mapping(uint256 => uint128) private totalOfGroup;
    mapping(address => uint256[MAXIMUM_LEVEL]) private levelBalances;
    mapping(uint64 => GroupPointer[MAXIMUM_LEVEL - 1]) private itemsInGroup; // 1 smaller because level zero isn't represented

    uint64 [MAXIMUM_LEVEL] private interestBonuses;
    uint128 private elementSize;
    uint128 private nextElementIndex;
    uint256 private nextTokenId;
    uint256 private maximumElementMint;
    uint256 private elementMintCost;
    uint256 private forgeCost;

    uint256 public highestDefinedGroup;

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
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
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
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId));

        manager = ISocialTokenManager(newManager);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (bytes(baseTokenURI).length == 0)
            return "";

        string memory path = string(abi.encodePacked(baseTokenURI, dataMap[tokenId].level.toString()));
        path = string(abi.encodePacked(path, "/"));
        path = string(abi.encodePacked(path, dataMap[tokenId].group.toString()));
        path = string(abi.encodePacked(path, "/"));
        path = string(abi.encodePacked(path, dataMap[tokenId].index.toString()));

        return path;
    }

    function setBaseURI(string memory newURI) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        baseTokenURI = newURI;
    }

    function setForgeValues(uint256 newMax, uint256 newElementCost, uint256 newForgeCost) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        maximumElementMint = newMax;
        elementMintCost = newElementCost;
        forgeCost = newForgeCost;
    }

    function forgeElement() public {
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
            totalOfGroup[0]++;
            nextTokenId++;

            nextElementIndex = (nextElementIndex + 1) % elementSize;
        }
    }

    function forge(uint256 templateId, uint256 materialId1, uint256 materialId2) public {

        NFTData memory forgedItem = dataMap[templateId];

        // check constraints
        // ownerOf takes care of checking that the ID has been minted
        require(ownerOf(templateId) == _msgSender());
        require(ownerOf(materialId1) == _msgSender());
        require(ownerOf(materialId2) == _msgSender());
        require(highestDefinedGroup > 0);
        require(forgedItem.level < MAXIMUM_LEVEL - 2);
        require(forgedItem.group == 0 || itemsInGroup[forgedItem.group][forgedItem.level].size > 0);
        require(dataMap[materialId1].level == forgedItem.level);
        require(dataMap[materialId2].level == forgedItem.level);

        // attempt to deduct fuel cost
        if (forgeCost > 0) {
            manager.getTokenContract().forge(_msgSender(), int256(forgeCost));
        }

        // delete the existing NFTs
        levelBalances[_msgSender()][forgedItem.level] -= 3;

        totalOfGroup[forgedItem.group] -= 1;
        delete(dataMap[templateId]);
        _burn(templateId);
        
        totalOfGroup[dataMap[materialId1].group] -= 1;
        delete(dataMap[materialId1]);
        _burn(materialId1);
        
        totalOfGroup[dataMap[materialId2].group] -= 1;
        delete(dataMap[materialId2]);
        _burn(materialId2);
        
        // mint the new NFT
        _safeMint(_msgSender(), nextTokenId);
        forgedItem = _upgradeNFT(forgedItem);
        dataMap[nextTokenId] = forgedItem;
        itemsInGroup[forgedItem.group][forgedItem.level].nextIndex = 
            (itemsInGroup[forgedItem.group][forgedItem.level].nextIndex + 1) % itemsInGroup[forgedItem.group][forgedItem.level].size;
        levelBalances[_msgSender()][forgedItem.level]++;
        totalOfGroup[forgedItem.group]++;
        nextTokenId++;
    }

    function _upgradeNFT(NFTData memory template) private view returns(NFTData memory newNFT) {
        if (template.level == 0) {
            // to go from level 0 to level 1 we're going to have to pick a group to assign it to
            uint256 selectedGroup = highestDefinedGroup;
            while (selectedGroup > 1 && totalOfGroup[selectedGroup - 1] <= totalOfGroup[selectedGroup]) {
                selectedGroup--;
            }

            template.group = uint64(selectedGroup);
        }
        
        template.level++;
        template.index = itemsInGroup[template.group][template.level].nextIndex;

        return template;
    }

    function setGroupSizes(uint64 group, uint128[] memory sizes) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(sizes.length < MAXIMUM_LEVEL);
        require(group != 0);

        GroupPointer memory thisDatum;
        bool zeoredOut = true;

        for (uint256 i = 0;i <= sizes.length - 1;i++) {
            thisDatum = itemsInGroup[group][i];
            thisDatum.size = sizes[i];

            if (thisDatum.nextIndex >= thisDatum.size) {
                thisDatum.nextIndex = 0;
            }

            itemsInGroup[group][i] = thisDatum;

            if (sizes[i] > 0) {
                zeoredOut = false;
            }
        }

        if (group > highestDefinedGroup) {
            highestDefinedGroup = group;
        }
        else if (group == highestDefinedGroup && zeoredOut) {
            highestDefinedGroup--;
        }
    }

    function resizeElementLibarary(uint128 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        elementSize = size;
        if (nextElementIndex > size) {
            nextElementIndex = 0;
        }
    }

    function getGroupSizes(uint64 group) public view returns(uint128[MAXIMUM_LEVEL - 1] memory) {
        uint128[MAXIMUM_LEVEL - 1] memory sizes;

        for (uint256 i = 0;i < MAXIMUM_LEVEL - 1;i++) {
            sizes[i] = itemsInGroup[group][i].size;
        }

        return sizes;
    }
}
