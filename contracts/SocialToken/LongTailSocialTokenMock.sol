// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../SocialTokenManager/ISocialTokenManager.sol";
import "./LongTailSocialToken.sol";

contract LongTailSocialTokenMock is LongTailSocialToken {
    ISocialTokenManager private manager;

    constructor(
        address manager_,
        address[] memory defaultOperators_
    ) LongTailSocialToken(manager_, defaultOperators_) {}

    function mine() public override pure {}

    function getManager() external view returns (ISocialTokenManager) {
        return manager;
    }
}
