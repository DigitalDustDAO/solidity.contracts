// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IMeasureManager.sol";
import "./IRule34.sol";

contract Rule34 is IRule34, ERC20, ERC165 {

    IMeasureManager private manager;

    uint256 public immutable incrementalValue;

    constructor(uint256 incrementalValue_) ERC20("Rule 34", "R34") {
        incrementalValue = incrementalValue_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IRule34).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function setManager(address newManager) external {
        require(_msgSender() == address(manager));
        require(IMeasureManager(newManager).supportsInterface(type(IMeasureManager).interfaceId));

        manager = IMeasureManager(newManager);
    }

    function getTokenCost() public view returns(uint256 cost) {
        return totalSupply() * incrementalValue;
    }

    function awardRule34Token(address account) external {
        manager.authorize(_msgSender(), IMeasureManager.Sensitivity.Token);

        _mint(account, 10**decimals());
    }

    function removeRule34Token(address account) external returns(uint256 value) {
        manager.authorize(_msgSender(), IMeasureManager.Sensitivity.Token);

        _burn(account, 10**decimals());

        return getTokenCost();
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        revert("This token cannot be transfered");
        return false;
    }
}