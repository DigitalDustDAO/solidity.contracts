// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISocialTokenNFT {
    
    struct NFTData {
        uint8  level;
        uint64 group;
        uint64 index;
    } // 96 bits unused

    struct GroupData {
        uint32 uriIndex;
        uint64 size;
        uint64 current;
        uint64 salt;
        bool   auxEnabled;
    } // 24 bits unused

    event RewardIssued (
        address indexed recipiant,
        uint128 tokensRewarded,
        uint128 NFTsRewarded
    );

    event GroupDataChanged (
        uint8 indexed level,
        uint112 indexed group,
        uint64 oldSize,
        uint64 newSize,
        uint32 uriIndex,
        bool auxEnabled
    );

    event OwnershipTransferred (
        address indexed previousOwner, 
        address indexed newOwner
    );

    // event NFTUpgraded (
    //     address indexed owner,
    //     uint256 indexed id,
    //     uint8 level,
    //     uint64 group,
    //     uint64 index
    // );

    // Manager only function
    function setManager(address newManager) external;

    // Economy adjustment functions
    function transferOwnership(address newOwner) external;
    function setInterestBonus(uint8 level, uint64 newBonus) external;
    function setForgeValues(uint256 newElementCost, uint256 newForgeCost) external;
    function setURIs(uint32 index, string memory newURI, string memory newAuxURI) external;

    // Council functions
    function setGroupData(uint64 group, uint64[] memory sizes, bool[] memory auxVersionEnabled, uint32[] memory uriIndexes, uint64[] memory salts) external;
    function awardBounty(address recipient, uint256 tokenReward, NFTData[] memory nftAwards) external;

    // Public views
    function interestBonus(address account) external view returns(uint64);
    function getTokenInfo(uint256 tokenId) external view returns(uint8 level, uint64 group, uint64 index);
    function getURIsByIndex(uint32 index) external view returns(string memory baseURI, string memory auxURI);
    function getClaimableBountyCount(address account) external view returns(uint256 number);
}