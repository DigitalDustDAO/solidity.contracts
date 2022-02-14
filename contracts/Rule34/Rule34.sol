// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../ERC777.sol";
import "./IRule34.sol";

contract Rule34 is IRule34, ERC777, ERC165 {

    constructor(address[] memory defaultOperators_) ERC777("Rule 34", "R34", defaultOperators_) {
        _mint(_msgSender(), 1000000000000000000000000, "", "");
    }

    function setTokenData(uint128 startPos, uint128 resumePos, string memory insert) public {


    }

    function getTokenUri(address account, address nftContract) external view {

    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IRule34).interfaceId
            || super.supportsInterface(interfaceId);
    }

}