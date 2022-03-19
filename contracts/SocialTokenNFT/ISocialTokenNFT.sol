// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISocialTokenNFT {
    
    struct NFTData {
        uint8   level;
        uint112 group;
        uint104 index;
        uint32  salt;
    }

    struct GroupData {
        uint16  uriIndex;
        uint32  salt;
        uint104 size;
        uint104 current;
    }

    event RewardIssued (
        address indexed recipiant,
        uint128 tokensRewarded,
        uint128 NFTsRewarded
    );

    // Manager only function
    function setManager(address newManager) external;

    // Economy adjustment functions
    function transferOwnership(address newOwner) external;
    function setInterestBonus(uint256 level, uint64 newBonus) external;
    function setForgeValues(uint256 newMax, uint256 newElementCost, uint256 newForgeCost) external;
    function setURIs(uint16 index, string memory newURI, string memory newAuxURI) external;

    // Council functions
    function setGroupSizes(uint112 group, uint104[] memory sizes, uint16[] memory uriIndexes, uint32[] memory salts) external;
    function setAuxStatusForGroup(uint112 group, bool[] memory enabledForLevel) external;
    function resizeElementLibarary(uint104 size) external;
    function awardBounty(address recipient, uint256 tokenReward, NFTData[] memory nftAwards) external;

    // Public views
    function interestBonus(address account) external view returns(uint64);
    function getTokenInfo(uint256 tokenId) external view returns(NFTData memory info);
    function getBaseURIsByIndex(uint16 index) external view returns(string memory baseURI, string memory auxURI);
    function getClaimableBountyCount(address account) external view returns(uint256 number);
}