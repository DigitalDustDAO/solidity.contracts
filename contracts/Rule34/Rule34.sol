// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../ERC777.sol";
import "./IMeasureManager.sol";
import "./IRule34.sol";

contract Rule34 is IRule34, ERC777, ERC165 {

    IMeasureManager private manager;

    constructor(address[] memory defaultOperators_) ERC777("Rule 34", "R34", defaultOperators_) {
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager));
        require(IMeasureManager(newManager).supportsInterface(type(IMeasureManager).interfaceId));

        manager = IMeasureManager(newManager);
    }

    function setTokenData(uint128 startPos, uint128 resumePos, string memory insert) public {


    }

    function getTokenUri(address account, address nftContract) external view returns(string memory) {

    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IRule34).interfaceId
            || super.supportsInterface(interfaceId);
    }

}