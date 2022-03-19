// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialToken/ISocialToken.sol";
import "./IAuxCompatableNFT.sol";

contract LongTailSocialNFT is ISocialTokenNFT, IAuxCompatableNFT, ERC721, Ownable {
    using Strings for uint8;
    using Strings for uint104;
    using Strings for uint112;

    ISocialTokenManager internal manager;

    string[] public baseTokenURIs;
    string[] public auxTokenURIs;

    uint8 private constant MAXIMUM_LEVEL = 8;
    string private constant SLASH = "/";

    mapping(uint256 => NFTData) private dataMap;
    mapping(uint256 => uint256) private totalOfGroup;
    mapping(address => uint256[MAXIMUM_LEVEL]) private levelBalances;
    mapping(uint120 => GroupData[MAXIMUM_LEVEL - 1]) private itemsInGroup; // 1 smaller because level zero isn't represented
    mapping(uint120 => bool[MAXIMUM_LEVEL]) hasAuxVersion;
    mapping(address => NFTData[]) private unclaimedBounties;

    uint64[MAXIMUM_LEVEL] private interestBonuses;
    uint104 private elementSize;
    uint104 private elementIndex;

    uint256 public totalTokens;
    uint256 public maximumElementMint;
    uint256 public elementMintCost;
    uint256 public forgeCost;
    uint256 public highestDefinedGroup;

    constructor(address manager_) ERC721("Long Tail Social NFT", "LTSNFT") {
        manager = ISocialTokenManager(manager_);

        interestBonuses[0] = 32768;
        for(uint256 i = 1;i < MAXIMUM_LEVEL;i++) {
            interestBonuses[i] = interestBonuses[i - 1] * 2;
        }
    }

    /**
     * Integration functions
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return 
            interfaceId == type(ISocialTokenNFT).interfaceId ||
            interfaceId == type(IAuxCompatableNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Manager upgrade function
     */
    function setManager(address newManager) external {
        require(_msgSender() == address(manager));
        require(ISocialTokenManager(newManager).supportsInterface(type(ISocialTokenManager).interfaceId));

        manager = ISocialTokenManager(newManager);
    }

    /**
     * Economy adjustment functions
     */
    function transferOwnership(address newOwner) public override(ISocialTokenNFT, Ownable) {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        _transferOwnership(newOwner);
    }

    function setInterestBonus(uint256 level, uint64 newBonus) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(level < MAXIMUM_LEVEL);

        interestBonuses[level] = newBonus;
    }

    function setForgeValues(
        uint256 newMax,
        uint256 newElementCost,
        uint256 newForgeCost
    ) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        maximumElementMint = newMax;
        elementMintCost = newElementCost;
        forgeCost = newForgeCost;
    }

    function setURIs(uint16 index, string memory newURI, string memory newAuxURI) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(index <= baseTokenURIs.length);

        if (index == baseTokenURIs.length) {
            baseTokenURIs.push(newURI);
            auxTokenURIs.push(newAuxURI);
        }
        else {
            if (bytes(newURI).length > 0) {
                baseTokenURIs[index] = newURI;
            }

            if (bytes(newAuxURI).length > 0) {
                auxTokenURIs[index] = newAuxURI;
            }
        }
    }

    /**
     * Council functions
     */
    function setGroupSizes(uint112 group, uint104[] memory sizes, uint16[] memory uriIndexes, uint32[] memory salts) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(sizes.length < MAXIMUM_LEVEL);
        require(sizes.length > 0 && sizes[0] > 0);
        require(group <= highestDefinedGroup + 1);
        require(group != 0);

        GroupData memory thisDatum = itemsInGroup[group][0];

        for (uint256 i = 0;i <= sizes.length - 1;i++) {
            thisDatum = itemsInGroup[group][i];
            thisDatum.size = sizes[i];

            if (thisDatum.current > thisDatum.size) {
                thisDatum.current = 0;
            }

            if (uriIndexes.length > i) {
                thisDatum.uriIndex = uriIndexes[i];
            }

            if (salts.length > i) {
                thisDatum.salt = salts[i];
            }

            itemsInGroup[group][i] = thisDatum;
        }

        if (group > highestDefinedGroup) {
            highestDefinedGroup = group;
        }
    }

    function setAuxStatusForGroup(uint112 group, bool[] memory enabledForLevel) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(enabledForLevel.length < MAXIMUM_LEVEL);
        require(group <= highestDefinedGroup);

        if (group == 0) {
            if (enabledForLevel.length >= 1) {
                hasAuxVersion[0][0] = enabledForLevel[0];
            }
        }
        else {
            for (uint256 i = 0;i < enabledForLevel.length;i++) {
                hasAuxVersion[group][i] = enabledForLevel[i];
            }
        }
    }

    function resizeElementLibarary(uint104 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        elementSize = size;
        if (elementIndex > size) {
            elementIndex = 0;
        }
    }

    function awardBounty(address recipient, uint256 tokenReward, NFTData[] memory nftAwards) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(recipient != address(0));

        if (tokenReward > 0) {
            manager.getTokenContract().award(recipient, int256(tokenReward));
        }

        for(uint256 i = 0;i < nftAwards.length;i++) {
            unclaimedBounties[recipient].push(nftAwards[i]);
        }

        emit RewardIssued(recipient, uint128(tokenReward), uint128(nftAwards.length));
    }

    /**
     * Public views
     */
    function interestBonus(address account) external view returns(uint64) {
        uint256 maxLevel = MAXIMUM_LEVEL - 1;
        unchecked {
            while(maxLevel >= 0 && levelBalances[account][maxLevel] == 0) {
                if (maxLevel == 0) {
                    return 0;
                }

                maxLevel--;
            }

            return interestBonuses[maxLevel];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory uri) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string storage baseURI;
        if (dataMap[tokenId].level == 0) {
            baseURI = baseTokenURIs[0];
        } 
        else {
            baseURI = baseTokenURIs[itemsInGroup[dataMap[tokenId].group][dataMap[tokenId].level - 1].uriIndex];
        }

        if (bytes(baseURI).length == 0)
            return "";

        return string(
            abi.encodePacked(baseURI, 
                dataMap[tokenId].level.toString(), SLASH, 
                dataMap[tokenId].group.toString(), SLASH,
                dataMap[tokenId].index.toString()
            )
        );
    }

    function tokenAuxURI(uint256 tokenId) public view virtual returns(bool different, string memory uri) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (dataMap[tokenId].level == 0 || !manager.hasAuxToken(_msgSender()) || hasAuxVersion[dataMap[tokenId].group][dataMap[tokenId].level]) {
            return (false, tokenURI(tokenId));
        }

        string storage auxURI;
        auxURI = auxTokenURIs[itemsInGroup[dataMap[tokenId].group][dataMap[tokenId].level - 1].uriIndex];

        if (bytes(auxURI).length == 0) {
            return (false, tokenURI(tokenId));
        }

        NFTData memory datum = dataMap[tokenId];
        datum.salt = itemsInGroup[datum.group][datum.level - 1].salt;

        return (true, string(abi.encodePacked(auxURI, keccak256(abi.encode(datum)))));
    }

    function getTokenInfo(uint256 tokenId) public view returns(NFTData memory info) {
        return dataMap[tokenId];
    }

    function getBaseURIsByIndex(uint16 index) public view returns(string memory baseURI, string memory auxURI) {
        require(index < baseTokenURIs.length);

        return (baseTokenURIs[index], auxTokenURIs[index]);
    }

    function getGroupSizes(uint64 group) public view returns(uint128[MAXIMUM_LEVEL - 1] memory) {
        uint128[MAXIMUM_LEVEL - 1] memory sizes;

        for (uint256 i = 0;i < MAXIMUM_LEVEL - 1;i++) {
            sizes[i] = itemsInGroup[group][i].size;
        }

        return sizes;
    }

    function getClaimableBountyCount(address account) public view returns(uint256 number) {
        return unclaimedBounties[account].length;
    }

    /**
     * User functions
     */
    function collectBounties(uint256 number) public {
        
        NFTData memory item;
        while (unclaimedBounties[_msgSender()].length > 0 && number > 0) {
            item = unclaimedBounties[_msgSender()][unclaimedBounties[_msgSender()].length - 1];

            if (item.level == 0 && (item.index == 0 || item.index > elementSize)) {
                item.index = (elementIndex + 1) % elementSize;
                elementIndex = item.index;
            }
            else if (item.index == 0 || item.index > itemsInGroup[item.group][item.level].size) {
                item.index = (itemsInGroup[item.group][item.level].current + 1) % itemsInGroup[item.group][item.level].size;
                itemsInGroup[item.group][item.level].current = item.index;
            }

            unclaimedBounties[_msgSender()].pop();
            _safeMint(_msgSender(), item);

            number--;
        }
    }

    function forgeElement() public {
        forgeElements(1);
    }

    function forgeElements(uint256 quantity) public {
        require(quantity <= maximumElementMint);
        require(quantity > 0);
        require(elementSize > 0);

        manager.getTokenContract().award(_msgSender(), int256(quantity * elementMintCost) * -1);

        for (uint256 i = 0;i < quantity;i++) {
            elementIndex = (elementIndex + 1) % elementSize;
            _safeMint(_msgSender(), NFTData (0, 0, elementIndex, 0));
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
        require(forgedItem.level < MAXIMUM_LEVEL - 1);
        require(forgedItem.group == 0 || itemsInGroup[forgedItem.group][forgedItem.level].size > 0);
        require(dataMap[materialId1].level == forgedItem.level);
        require(dataMap[materialId2].level == forgedItem.level);

        // attempt to deduct fuel cost
        if (forgeCost > 0) {
            manager.getTokenContract().award(_msgSender(), int256(forgeCost) * -1);
        }

        // delete the old NFTs
        _burn(templateId);
        _burn(materialId1);
        _burn(materialId2);
        
        // mint the new NFT
        forgedItem = _upgradeNFT(forgedItem);
        itemsInGroup[forgedItem.group][forgedItem.level].current = forgedItem.index;
        _safeMint(_msgSender(), _upgradeNFT(forgedItem));
    }

    function _upgradeNFT(NFTData memory template) private view returns(NFTData memory newNFT) {
        if (template.level == 0) {
            // To go from level 0 to level 1 we're going to have to pick a group to assign it to
            uint256 selectedGroup = highestDefinedGroup;
            while (selectedGroup > 1 && totalOfGroup[selectedGroup - 1] <= totalOfGroup[selectedGroup]) {
                selectedGroup--;
            }

            template.group = uint64(selectedGroup);
        }
        
        // Instead of using "template.level - 1" here we're just incrementing it after using it.
        template.index = (itemsInGroup[template.group][template.level].current + 1) % itemsInGroup[template.group][template.level].size;
        template.level++;

        return template;
    }

    function _safeMint(address to, NFTData memory tokenData) internal {
        _safeMint(to, totalTokens, "");
        dataMap[totalTokens] = tokenData;
        levelBalances[to][tokenData.level]++;
        totalOfGroup[tokenData.group]++;
        totalTokens++;
    }

    function _burn(uint256 tokenId) internal override {
        levelBalances[ownerOf(tokenId)][dataMap[tokenId].level]--;
        totalOfGroup[dataMap[tokenId].group]--;
        delete(dataMap[tokenId]);
        super._burn(tokenId);
    }
}
