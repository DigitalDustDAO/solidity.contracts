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
    string private constant NOT_ENABLED = "Cannot forge: Level not enabled.";
    string private constant INVALID_INPUT = "Cannot forge: Inputs invalid.";
    string private constant OUTBOUNDS = "Out of bounds.";
    string private constant CREATES_HOLES = "Array cannot expand by more than 1 element.";
    bytes32 private constant AUX_URI_UNLOCK_R = "0x556e6c6f636b2072756c6520333420";
    bytes32 private constant AUX_URI_UNLOCK_S = "66756e6374696f6e616c697479";

    mapping(uint256 => NFTData) private dataMap;
    mapping(uint256 => uint256) private totalOfGroup;
    mapping(address => uint256[MAXIMUM_LEVEL]) private levelBalances;
    mapping(uint120 => GroupData[MAXIMUM_LEVEL - 1]) private itemsInGroup; // 1 smaller because level zero isn't represented
    mapping(uint120 => bool[MAXIMUM_LEVEL - 1]) hasAuxVersion;
    mapping(address => NFTData[]) private unclaimedBounties;

    uint64[MAXIMUM_LEVEL] private interestBonuses;
    uint104 private elementSize;
    uint104 private elementIndex;
    uint8 public maximumElementMint;

    uint256 public totalTokens;
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

    function setInterestBonus(uint256 level, uint64 newBonus) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(level < MAXIMUM_LEVEL);

        interestBonuses[level] = newBonus;
    }

    function setForgeValues(uint8 newMax, uint256 newElementCost, uint256 newForgeCost) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        maximumElementMint = newMax;
        elementMintCost = newElementCost;
        forgeCost = newForgeCost;

        emit ForgeCostSet(newMax, newElementCost, newForgeCost);
    }

    function setURIs(uint16 index, string memory newURI, string memory newAuxURI) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(index <= baseTokenURIs.length, CREATES_HOLES);

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
        require(sizes.length < MAXIMUM_LEVEL, OUTBOUNDS);
        require(sizes.length > 0 && sizes[0] > 0, OUTBOUNDS);
        require(group <= highestDefinedGroup + 1, CREATES_HOLES);
        require(group != 0, OUTBOUNDS);

        GroupData memory thisDatum = itemsInGroup[group][0];

        for (uint256 i = 0;i <= sizes.length - 1;i++) {
            if (itemsInGroup[group][i].size != sizes[i]) {
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

                emit GroupSizeChanged(uint8(i + 1), group, itemsInGroup[group][i].size, sizes[i]);
                itemsInGroup[group][i] = thisDatum;
            }
        }

        if (group > highestDefinedGroup) {
            highestDefinedGroup = group;
        }
    }

    // NOTE: level 0 is not represented (cannot have an aux version), so the enabledForLevel array size
    //  should be reduced by 1 when calling this function.
    function setAuxStatusForGroup(uint112 group, bool[] memory enabledForLevel) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(enabledForLevel.length < MAXIMUM_LEVEL, OUTBOUNDS);
        require(group <= highestDefinedGroup, OUTBOUNDS);
        require(group > 0, OUTBOUNDS); // elements cannot have an aux version.

        for (uint256 i = 0;i < enabledForLevel.length;i++) {
            hasAuxVersion[group][i] = enabledForLevel[i];
        }
    }

    function resizeElementLibarary(uint104 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        emit GroupSizeChanged(0, 0, elementSize, size);

        elementSize = size;
        if (elementIndex > size) {
            elementIndex = 0;
        }
    }

    function awardBounty(address recipient, uint256 tokenReward, NFTData[] memory nftAwards) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(recipient != address(0));

        if (tokenReward > 0) {
            manager.getTokenContract().award(recipient, int256(tokenReward), "bounty award");
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

    function tokenAuxURI(uint256 tokenId, bytes32 signedMessage) public view virtual returns(bool different, string memory uri) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        NFTData memory tokenData = dataMap[tokenId];
        address signer = ecrecover(signedMessage, 0, AUX_URI_UNLOCK_R, AUX_URI_UNLOCK_S);

        if (ownerOf(tokenId) != signer || !manager.hasAuxToken(signer)
                || tokenData.level == 0 || hasAuxVersion[tokenData.group][tokenData.level - 1]) {
            return (false, tokenURI(tokenId));
        }

        GroupData storage groupData = itemsInGroup[tokenData.group][tokenData.level - 1];
        string storage auxURI = auxTokenURIs[groupData.uriIndex];
        tokenData.salt = groupData.salt;

        if (bytes(auxURI).length == 0) {
            return (false, tokenURI(tokenId));
        }

        return (true, string(abi.encodePacked(auxURI, keccak256(abi.encode(tokenData)))));
    }

    function hasAuxURI(uint256 tokenId) public view virtual returns(bool auxURIExists) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        NFTData memory tokenData = dataMap[tokenId];

        if (tokenData.level == 0) {
            return false;
        }
        else {
            return hasAuxVersion[tokenData.group][tokenData.level - 1];
        }
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
        require(quantity <= maximumElementMint, INVALID_INPUT);
        require(quantity > 0, INVALID_INPUT);
        require(elementSize > 0, NOT_ENABLED);

        manager.getTokenContract().award(_msgSender(), int256(quantity * elementMintCost) * -1, "forging cost");

        for (uint256 i = 0;i < quantity;i++) {
            elementIndex = (elementIndex + 1) % elementSize;
            _safeMint(_msgSender(), NFTData (0, 0, elementIndex, 0));
        }
    }

    function forge(uint256 templateId, uint256 materialId) public {

        NFTData memory forgedItem = dataMap[templateId];
        NFTData storage material = dataMap[materialId];

        // check constraints
        // ownerOf takes care of checking that the ID has been minted
        require(ownerOf(templateId) == _msgSender(), INVALID_INPUT);
        require(ownerOf(materialId) == _msgSender(), INVALID_INPUT);
        require(highestDefinedGroup > 0, NOT_ENABLED);
        require(forgedItem.level < MAXIMUM_LEVEL - 1, NOT_ENABLED);
        require(forgedItem.group == 0 || itemsInGroup[forgedItem.group][forgedItem.level].size > 0, NOT_ENABLED);
        require(material.level == forgedItem.level, INVALID_INPUT);

        // attempt to deduct fuel cost
        if (forgeCost > 0) {
            manager.getTokenContract().award(_msgSender(), int256(forgeCost) * -1, "forging cost");
        }

        // delete the old NFTs
        _burn(templateId);
        _burn(materialId);
        
        // mint the new NFT
        forgedItem = _upgradeNFT(forgedItem);
        itemsInGroup[forgedItem.group][forgedItem.level].current = forgedItem.index;
        _safeMint(_msgSender(), _upgradeNFT(forgedItem));
    }

    // function _recoverSigner(bytes32 _signedMessage, bytes memory _signature) private pure returns (address)
    // {
    //     (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);

    //     return ecrecover(_signedMessage, v, r, s);
    // }

    // function _splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
    //     require(sig.length == 65, "invalid signature length");

    //     assembly {
    //         /*
    //         First 32 bytes stores the length of the signature

    //         add(sig, 32) = pointer of sig + 32
    //         effectively, skips first 32 bytes of signature

    //         mload(p) loads next 32 bytes starting at the memory address p into memory
    //         */

    //         // first 32 bytes, after the length prefix
    //         r := mload(add(sig, 32))
    //         // second 32 bytes
    //         s := mload(add(sig, 64))
    //         // final byte (first byte of the next 32 bytes)
    //         v := byte(0, mload(add(sig, 96)))
    //     }

    //     // implicitly return (r, s, v)
    // }

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
