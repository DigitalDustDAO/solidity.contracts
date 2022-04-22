// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../SocialTokenManager/ISocialTokenManager.sol";
import "../SocialToken/LongTailSocialToken.sol";

contract LongTailSocialTokenMock is LongTailSocialToken {
    address _sender;

    constructor(
        address manager_
    ) LongTailSocialToken(manager_, new address[](0)) {}

    function setMsgSender(address sender_) public {
        _sender = sender_;
    }

    function _msgSender() internal view override returns (address) {
        return _sender == address(0) ? msg.sender : _sender;
    }

    function getCurrentDay() public override virtual view returns (uint256) {
        return 7;
    }

    // function getManager() external view returns (ISocialTokenManager) {
    //     return manager;
    // }

    // function getManagerAddress() external view returns (address) {
    //     return address(manager);
    // }

    function getSender() external view returns (address) {
        return _msgSender();
    }

    function getLastInterestAdjustment() external view returns (uint) {
        return lastInterestAdjustment;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount, "", "");
    }
}
