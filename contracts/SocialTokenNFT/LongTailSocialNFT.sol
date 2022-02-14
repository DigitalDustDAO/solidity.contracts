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
    mapping(address => NFTData[]) private unclaimedBounties;

    uint64 [MAXIMUM_LEVEL] private interestBonuses;
    uint128 private elementSize;
    uint128 private nextElementIndex;
    uint256 private nextTokenId;

    uint256 public maximumElementMint;
    uint256 public elementMintCost;
    uint256 public forgeCost;
    uint256 public highestDefinedGroup;
    int256 public tokenRewardPerBounty;

    constructor(address manager_) ERC721("Long Tail Social NFT", "LTSNFT") {
        manager = ISocialTokenManager(manager_);

        interestBonuses[0] = 32768;
        for(uint256 i = 1;i < MAXIMUM_LEVEL;i++) {
            interestBonuses[i] = interestBonuses[i - 1] * 2;
        }
    }

    /**
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return 
            interfaceId == type(ISocialTokenNFT).interfaceId
            || super.supportsInterface(interfaceId);
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
    function setInterestBonus(uint256 level, uint64 newBonus) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(level <= MAXIMUM_LEVEL);

        interestBonuses[level] = newBonus;
    }

    function setForgeValues(uint256 newMax, uint256 newElementCost, uint256 newForgeCost, uint256 rewardPerBounty) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        maximumElementMint = newMax;
        elementMintCost = newElementCost;
        forgeCost = newForgeCost;
        tokenRewardPerBounty = int256(rewardPerBounty);
    }

    function setBaseURI(string memory newURI) external {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        baseTokenURI = newURI;
    }

    /**
     * Council functions
     */
    function setGroupSizes(uint64 group, uint128[] memory sizes) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(sizes.length < MAXIMUM_LEVEL);
        require(sizes.length > 0 && sizes[0] > 0);
        require(group <= highestDefinedGroup + 1);
        require(group != 0);

        GroupPointer memory thisDatum;

        for (uint256 i = 0;i <= sizes.length - 1;i++) {
            thisDatum = itemsInGroup[group][i];
            thisDatum.size = sizes[i];

            if (thisDatum.nextIndex >= thisDatum.size) {
                thisDatum.nextIndex = 0;
            }

            itemsInGroup[group][i] = thisDatum;
        }

        if (group > highestDefinedGroup) {
            highestDefinedGroup = group;
        }
    }

    function resizeElementLibarary(uint128 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        elementSize = size;
        if (nextElementIndex > size) {
            nextElementIndex = 0;
        }
    }

    function awardBounty(address recipiant, bool tokenReward, NFTData[] memory nftAwards) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(recipiant != address(0));

        if (tokenReward) {
            manager.getTokenContract().forge(recipiant, tokenRewardPerBounty);
        }

        for(uint256 i = 0;i < nftAwards.length;i++) {
            unclaimedBounties[recipiant].push(nftAwards[i]);
        }

        emit RewardIssued(recipiant, tokenReward ? int128(tokenRewardPerBounty) : int128(0), uint128(nftAwards.length));
    }

    /**
     * Public views
     */
    function interestBonus(address account) external view returns(uint64) {
        int256 maxLevel = int(MAXIMUM_LEVEL);
        unchecked {
            while(maxLevel >= 0 && levelBalances[account][uint256(maxLevel)] == 0) {
                maxLevel--;
            }

            return maxLevel >= 0 ? interestBonuses[uint256(maxLevel)] : 0;
        }
    }

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
                item.index = nextElementIndex;
                nextElementIndex = (nextElementIndex + 1) % elementSize;
            }
            else if (item.index == 0 || item.index > itemsInGroup[item.group][item.level].size) {
                item.index = itemsInGroup[item.group][item.level].nextIndex;
                itemsInGroup[item.group][item.level].nextIndex = 
                    (itemsInGroup[item.group][item.level].nextIndex + 1) % itemsInGroup[item.group][item.level].size;
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

        manager.getTokenContract().forge(_msgSender(), int256(quantity * elementMintCost) * -1);

        for (uint256 i = 0;i < quantity;i++) {
            _safeMint(_msgSender(), NFTData (0, 0, nextElementIndex));
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
        require(forgedItem.level < MAXIMUM_LEVEL - 1);
        require(forgedItem.group == 0 || itemsInGroup[forgedItem.group][forgedItem.level].size > 0);
        require(dataMap[materialId1].level == forgedItem.level);
        require(dataMap[materialId2].level == forgedItem.level);

        // attempt to deduct fuel cost
        if (forgeCost > 0) {
            manager.getTokenContract().forge(_msgSender(), int256(forgeCost) * -1);
        }

        // delete the old NFTs
        _burn(templateId);
        _burn(materialId1);
        _burn(materialId2);
        
        // mint the new NFT
        _safeMint(_msgSender(), _upgradeNFT(forgedItem));
    }

    function _upgradeNFT(NFTData memory template) private returns(NFTData memory newNFT) {
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
        itemsInGroup[template.group][template.level].nextIndex = 
            (itemsInGroup[template.group][template.level].nextIndex + 1) % itemsInGroup[template.group][template.level].size;

        return template;
    }

    function _safeMint(address to, NFTData memory tokenData) internal {
        _safeMint(to, nextTokenId, "");
        dataMap[nextTokenId] = tokenData;
        levelBalances[to][tokenData.level]++;
        totalOfGroup[tokenData.group]++;
        nextTokenId++;
    }

    function _burn(uint256 tokenId) internal override {
        levelBalances[ownerOf(tokenId)][dataMap[tokenId].level]--;
        totalOfGroup[dataMap[tokenId].group]--;
        delete(dataMap[tokenId]);
        super._burn(tokenId);
    }
}
