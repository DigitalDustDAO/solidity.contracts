// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ILongTailManager.sol";
import "./IDigitalDustDAO.sol";

contract LongTailBootstrapper is ILongTailManager {

    IDigitalDustDAO DAOAddress;
    uint256 DAOid;

    constructor(address DAO, uint256 id) {
        DAOAddress = IDigitalDustDAO(DAO);
        DAOid = id;
    }

    // TODO: Self Destruct
}