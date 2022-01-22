// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ISocialTokenManager.sol";
import "./IDigitalDustDAO.sol";

contract LongTailBootstrapper is ISocialTokenManager {

    IDigitalDustDAO DAOAddress;
    uint256 DAOid;

    constructor(address DAO, uint256 id) {
        DAOAddress = IDigitalDustDAO(DAO);
        DAOid = id;
    }

    // TODO: Self Destruct
}