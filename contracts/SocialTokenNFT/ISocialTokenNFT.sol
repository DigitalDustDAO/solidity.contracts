// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISocialTokenNFT {
    
    struct NFTData {
        uint8  level;
        uint64 group;
        uint96 index;
        uint32 salt;
        uint56 padding;
    }

    struct GroupData {
        uint24 uriIndex;
        uint96 size;
        uint96 current;
        bool   auxEnabled;
        uint32 salt;
    }

    event RewardIssued (
        address indexed recipiant,
        uint128 tokensRewarded,
        uint128 NFTsRewarded
    );

    event GroupDataChanged (
        uint8 indexed level,
        uint112 indexed group,
        uint96 oldSize,
        uint96 newSize,
        uint24 uriIndex,
        bool auxEnabled
    );

    event OwnershipTransferred (
        address indexed previousOwner, 
        address indexed newOwner
    );

    // Manager only function
    function setManager(address newManager) external;

    // Economy adjustment functions
    function transferOwnership(address newOwner) external;
    function setInterestBonus(uint8 level, uint64 newBonus) external;
    function setForgeValues(uint256 newElementCost, uint256 newForgeCost) external;
    function setURIs(uint24 index, string memory newURI, string memory newAuxURI) external;

    // Council functions
    function setGroupData(uint64 group, uint96[] memory sizes, bool[] memory auxVersionEnabled, uint24[] memory uriIndexes, uint32[] memory salts) external;
    function resizeElementLibarary(uint96 size) external;
    function awardBounty(address recipient, uint256 tokenReward, NFTData[] memory nftAwards) external;

    // Public views
    function interestBonus(address account) external view returns(uint64);
    function getTokenInfo(uint256 tokenId) external view returns(uint8 level, uint64 group, uint96 index);
    function getURIsByIndex(uint24 index) external view returns(string memory baseURI, string memory auxURI);
    function getClaimableBountyCount(address account) external view returns(uint256 number);
}