// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../SocialTokenManager/ISocialTokenManager.sol";
import "./LongTailSocialToken.sol";

contract LongTailSocialTokenMock is LongTailSocialToken {
    address _sender;

    constructor(
        address manager_,
        address[] memory defaultOperators_
    ) LongTailSocialToken(manager_, defaultOperators_) {}

    function setMsgSender(address sender_) public {
        _sender = sender_;
    }

    function _msgSender() internal view override returns (address) {
        if (_sender != address(0)) {
            return _sender;
        } else {
            return msg.sender;
        }
    }

    function getCurrentDay() public override virtual view returns (uint256) {
        return 7;
    }

    function mine() public override pure {}

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }

    function getManagerAddress() external view returns (address) {
        return address(manager);
    }

    function getSender() external view returns (address) {
        return _msgSender();
    }

    function getLastInterestAdjustment() external view returns (uint) {
        return lastInterestAdjustment;
    }
}
