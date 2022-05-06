// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../SocialTokenNFT/ERC721.sol";
import "../SocialTokenNFT/SizeSortedList.sol";
import "../SocialTokenNFT/ISocialTokenNFT.sol";
import "../SocialTokenNFT/IAuxCompatableNFT.sol";
import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/ISocialToken.sol";

contract LongTailSocialNFT is ISocialTokenNFT, IAuxCompatableNFT, ERC721, SizeSortedList {
    using Strings for uint256;

    ISocialTokenManager public manager;

    string[] private baseTokenURIs;
    string[] private auxTokenURIs;

    bytes32 private immutable AUX_URI_UNLOCK;
    uint256 private constant MAXIMUM_LEVEL = 8;
    string private SLASH = "/";
    string private FORGE_COST = "Forging cost";
    string private NOT_ENABLED = "Cannot forge: Not enabled";

    mapping(uint256 => NFTData) private dataMap;
    mapping(address => uint32[MAXIMUM_LEVEL]) private levelBalances;
    mapping(uint256 => GroupData[MAXIMUM_LEVEL - 1]) private groupData; // 1 smaller because level zero isn't represented
    mapping(address => NFTData[]) private unclaimedBounties;

    uint64[MAXIMUM_LEVEL] private interestBonuses;
    uint64 private elementSize;
    uint64 private elementIndex;
    uint64 internal highestDefinedGroup;
    address public owner;
    uint256 public tokenCount;
    int256 private elementMintCost;
    int256 private forgeCost;

    constructor(address manager_, bytes32 auxUriUnlock) ERC721("Long Tail Social NFT", "LTSNFT") {
        manager = ISocialTokenManager(manager_);
        AUX_URI_UNLOCK = auxUriUnlock;

        interestBonuses[0] = 32768;
        for(uint256 i = 1;i < MAXIMUM_LEVEL;i++) {
            interestBonuses[i] = interestBonuses[i - 1] * 2;
        }

        elementMintCost = -10**19;
        owner = _msgSender();
        emit OwnershipTransferred(address(0), owner);
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
        require(IERC165(newManager).supportsInterface(type(ISocialTokenManager).interfaceId));

        manager = ISocialTokenManager(newManager);
    }

    /**
     * Economy adjustment functions
     */
    function transferOwnership(address newOwner) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setInterestBonus(uint8 level, uint64 newBonus) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(level < MAXIMUM_LEVEL);

        interestBonuses[level] = newBonus;
    }

    function setForgeValues(uint256 newElementCost, uint256 newForgeCost) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);

        elementMintCost = int256(newElementCost) * -1;
        forgeCost = int256(newForgeCost) * -1;
    }

    function setURIs(uint32 index, string memory newURI, string memory newAuxURI) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Maintainance);
        require(index <= baseTokenURIs.length, OUT_OF_BOUNDS);

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
    function setGroupData(uint64 group, uint64[] memory sizes, bool[] memory auxVersionEnabled, uint32[] memory uriIndexes, uint64[] memory salts) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);
        require(sizes.length < MAXIMUM_LEVEL, OUT_OF_BOUNDS);
        require(sizes.length > 0 && sizes[0] > 0, OUT_OF_BOUNDS);
        require(group <= highestDefinedGroup + 1, OUT_OF_BOUNDS);
        require(group != 0, OUT_OF_BOUNDS);

        GroupData memory thisDatum;

        for (uint256 i = 0;i <= sizes.length - 1;i++) {
            thisDatum.size = sizes[i];

            if (thisDatum.current > thisDatum.size) {
                thisDatum.current = 0;
            }

            if (uriIndexes.length > i) {
                thisDatum.uriIndex = uriIndexes[i];
            }

            if (auxVersionEnabled.length > i) {
                thisDatum.auxEnabled = auxVersionEnabled[i];
            }

            if (salts.length > i) {
                thisDatum.salt = salts[i];
            }

            if (groupData[group][i].size != thisDatum.size || groupData[group][i].uriIndex != thisDatum.uriIndex || 
                    groupData[group][i].auxEnabled != thisDatum.auxEnabled) {
                emit GroupDataChanged(uint8(i + 2), group, groupData[group][i].size, thisDatum.size, thisDatum.uriIndex, thisDatum.auxEnabled);
            }

            groupData[group][i] = thisDatum;
        }

        if (group > highestDefinedGroup) {
            highestDefinedGroup = group;
            addItemToSizeList(group);
        }
    }

    function setElementLibararySize(uint64 size) public {
        manager.authorize(_msgSender(), ISocialTokenManager.Sensitivity.Council);

        emit GroupDataChanged(0, 0, elementSize, size, 0, false);

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
        for (uint256 level = MAXIMUM_LEVEL;level > 0;level--) {
            if (levelBalances[account][level - 1] > 0) {
                return interestBonuses[level - 1];
            }
        }

        return 0;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory uri) {
        require(_exists(tokenId), NON_EXISTANT);

        string storage baseURI = dataMap[tokenId].level == 0 ? baseTokenURIs[0] :
            baseTokenURIs[groupData[dataMap[tokenId].group][dataMap[tokenId].level - 1].uriIndex];

        return bytes(baseURI).length == 0 ? "" : string(
            abi.encodePacked(baseURI, SLASH, 
                uint256(dataMap[tokenId].level).toString(), SLASH, 
                uint256(dataMap[tokenId].group).toString(), SLASH,
                uint256(dataMap[tokenId].index).toString()
            )
        );
    }

    function tokenAuxURI(uint256 tokenId, bytes memory signedMessage) public view virtual returns(bool isDifferent, string memory uri) {
        require(_exists(tokenId), NON_EXISTANT);

        NFTData storage tokenData = dataMap[tokenId];
        string storage auxURI = auxTokenURIs[groupData[tokenData.group][tokenData.level - 1].uriIndex];
        address signer = _recoverSigner(AUX_URI_UNLOCK, signedMessage);

        if (ownerOf(tokenId) != signer || !manager.hasAuxToken(signer) || tokenData.level == 0 
                || !groupData[tokenData.group][tokenData.level - 1].auxEnabled) {
            return (false, tokenURI(tokenId));
        }

        if (bytes(auxURI).length == 0) {
            return (false, tokenURI(tokenId));
        }

        return (true, string(abi.encodePacked(auxURI, SLASH, _toHexString(keccak256(abi.encode(_encodeToken(tokenData)))))));
    }

    function hasAuxURI(uint256 tokenId) public view virtual returns(bool auxURIExists) {
        require(_exists(tokenId), NON_EXISTANT);

        return dataMap[tokenId].level == 0 ? false : groupData[dataMap[tokenId].group][dataMap[tokenId].level - 1].auxEnabled;
    }

    function getTokenInfo(uint256 tokenId) public view returns(uint8 level, uint64 group, uint64 index) {
        level = dataMap[tokenId].level;
        group = dataMap[tokenId].group;
        index = dataMap[tokenId].index;
    }

    function getURIsByIndex(uint32 index) public view returns(string memory baseURI, string memory auxURI) {
        require(index < baseTokenURIs.length);

        return (baseTokenURIs[index], auxTokenURIs[index]);
    }

    function getGroupData(uint64 group) public view returns(GroupData[MAXIMUM_LEVEL] memory dataForGroup) {
        require(group <= highestDefinedGroup, OUT_OF_BOUNDS);

        if (group == 0) {
            dataForGroup[0].size = uint64(elementSize);
            dataForGroup[0].current = uint64(elementIndex);
        }
        else {
            for (uint256 i = 1;i < MAXIMUM_LEVEL;i++) {
                dataForGroup[i] = groupData[group][i - 1];
                dataForGroup[i].salt = 0;
            }
        }
    }

    function getClaimableBountyCount(address account) public view returns(uint256) {
        return unclaimedBounties[account].length;
    }

    function getForgeValues() public view returns(uint256 costToMintElements, uint256 costToForgeUpgrades) {
        costToMintElements = uint256(elementMintCost * -1);
        costToForgeUpgrades = uint256(forgeCost * -1);
    }

    /**
     * User functions
     */
    function collectBounties(uint256 number) public {
        NFTData memory item;
        NFTData[] storage bountyList = unclaimedBounties[_msgSender()];
        GroupData storage group;

        while (bountyList.length > 0 && number > 0) {
            item = bountyList[bountyList.length - 1];

            if (item.level == 0) {
                if (item.index > elementSize || item.index == 0)
                {
                    item.index = elementIndex;
                    elementIndex = (elementIndex + 1) % elementSize;
                }
            }
            else if (item.index > groupData[item.group][item.level - 1].size) {
                group = groupData[item.group][item.level - 1];
                item.index = group.current;
                group.current = (group.current + 1) % group.size;

                incrementSizeList(item.group);
            }

            bountyList.pop();
            _mint(_msgSender(), item);
            number--;
        }
    }

    function forgeElements(uint256 number) public {
        require(elementSize > 0, NOT_ENABLED);

        manager.getTokenContract().award(_msgSender(), elementMintCost * int256(number), FORGE_COST);

        NFTData memory template = NFTData (0, 0, elementIndex);
        while(number > 0) {
            _mint(_msgSender(), template);
            template.index = (template.index + 1) % elementSize;
            number--;
        }
        
        elementIndex = template.index;
    }

    function forge(uint256 templateId, uint256 materialId) public {
        NFTData memory forgedItem = dataMap[templateId];
        NFTData storage material = dataMap[materialId];

        // check constraints
        // ownerOf takes care of checking that the ID has been minted
        require(ownerOf(templateId) == _msgSender(), NOT_APPROVED);
        require(ownerOf(materialId) == _msgSender(), NOT_APPROVED);
        require(highestDefinedGroup > 0, NOT_ENABLED);
        require(forgedItem.level < MAXIMUM_LEVEL - 1, NOT_ENABLED);
        require(forgedItem.group == 0 || groupData[forgedItem.group][forgedItem.level].size > 0, NOT_ENABLED);
        require(material.level == forgedItem.level, INVALID_INPUT);

        // attempt to deduct forging cost
        if (forgeCost < 0) {
            manager.getTokenContract().award(_msgSender(), forgeCost, "forging cost");
        }

        // destroy the passed in items and update the size list
        if (material.level > 0) {
            decrementSizeList(material.group);
        }
        _burn(materialId);

        // upgrade the NFT
        if (forgedItem.level == 0) {
            forgedItem.group = getSizeListSmallestEntry();
            incrementSizeList(forgedItem.group);
        }

        // Instead of using "forgedItem.level - 1" here we're just incrementing it AFTER using it.
        forgedItem.index = groupData[forgedItem.group][forgedItem.level].current;
        groupData[forgedItem.group][forgedItem.level].current = 
            (groupData[forgedItem.group][forgedItem.level].current + 1) % groupData[forgedItem.group][forgedItem.level].size;
        forgedItem.level++;

        // mint the new NFT
        dataMap[templateId] = forgedItem;
        emit NFTUpgraded(_msgSender(), templateId, forgedItem.level, forgedItem.group, forgedItem.index);
    }

    function balanceOf(address ownerAddress) public view virtual override returns (uint256 total) {
        require(ownerAddress != address(0), INVALID_INPUT);
        
        for(uint256 i = 0;i < MAXIMUM_LEVEL;i++) {
            total += levelBalances[ownerAddress][i];
        }
    }

    // Internal functions
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from != address(0)) {
            levelBalances[from][dataMap[tokenId].level]--;
        }

        if (to != address(0)) {
            levelBalances[to][dataMap[tokenId].level]++;
        }
        else {
            delete(dataMap[tokenId]);
        }
    }

    function _encodeToken(NFTData storage tokenData) private view returns(bytes32) {
        uint256 total = tokenData.level;
        total = total << 64;
        total += tokenData.group;
        total = total << 64;
        total += tokenData.index;
        total = total << 64;
        total += groupData[tokenData.group][tokenData.level - 1].salt;
        total = total << 56;
        return bytes32(total);
    }

    function _toHexString(bytes32 _bytes32) private pure returns (bytes memory) {
        uint8 _f;
        uint8 _l;
        bytes memory bytesArray = new bytes(64);
        for (uint256 i = 0; i < bytesArray.length; i += 2) {

            _f = uint8(_bytes32[i/2] & 0x0f);
            _l = uint8(_bytes32[i/2] >> 4);

            bytesArray[i]     = _l < 10 ? bytes1(_l + 48) : bytes1(_l + 87);
            bytesArray[i + 1] = _f < 10 ? bytes1(_f + 48) : bytes1(_f + 87);
        }
        return bytesArray;
    }

    function _mint(address to, NFTData memory tokenData) internal {
        _mint(to, tokenCount);
        dataMap[tokenCount] = tokenData;
        tokenCount++;
    }

    function _recoverSigner(bytes32 message, bytes memory _signature) private pure returns (address) {
        require(_signature.length == 65, "Signature is invalid");

        bytes32 r; 
        bytes32 s;
        uint8 v;

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(_signature, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(_signature, 32))
            // second 32 bytes
            s := mload(add(_signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_signature, 96)))
        }

        return ecrecover(message, v, r, s);
    }
}
