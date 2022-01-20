pragma solidity 0.8.11;

import "./ILongTailAdministrator.sol";
import "./IDigitalDustDAO.sol";

contract LongTailBootstrapper is ILongTailAdministrator {

    IDigitalDustDAO DAOAddress;
    uint256 DAOid;

    constructor(address memory DAO, uint256 memory id) {
        DAOAddress = DAO;
        DAOid = id;
    }

    // TODO: Self Destruct
}