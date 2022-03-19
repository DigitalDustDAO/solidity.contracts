// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ERC1155WithAccess.sol";
import "./IDigitalDustDAO.sol";

contract DigitalDustDAO is IDigitalDustDAO, ERC1155WithAccess {
    uint64 constant private GRANT_RIGHTS = 200;
    uint64 constant private REVOKE_RIGHTS = 400;
    uint64 constant private APPLY_PENALTY = 400;
    uint64 constant private START_PROJECT = 500;

    mapping(uint256 => mapping(address => MemberBalance)) private _balances;

    mapping(uint256 => bool) private _activeProjects;

    constructor() ERC1155WithAccess("") {
        _balances[0][_msgSender()].rights = type(uint32).max;
        _activeProjects[0] = true;

        emit SetRights(0, address(0), _msgSender(), type(uint32).max);
    }

    function rightsOf(address account, uint256 id) public view returns (uint32 rights) {
        return _balances[id][account].rights;
    }

    function penaltyOf(address account, uint256 id) public view returns (uint32 penalty) {
        return _balances[id][account].penalty;
    }

    function accessOf(address account, uint256 id) public view returns (uint32 access) {
        return _balances[id][account].rights - _balances[id][account].penalty;
    }

    function getProjectActive(uint256 id) public view returns(bool) {
        return _activeProjects[id];
    }

    function setPenalty(address account, uint256 id, uint32 penalty) public {
        require(rightsOf(_msgSender(), id) >= APPLY_PENALTY, "Not enough rights to set penalty");
        _balances[id][account].penalty = penalty;

        emit SetPenalty(id, _msgSender(), account, penalty);
    }

    function consumeAccess(address account, uint256 id, uint32 amount) external {
        require(rightsOf(_msgSender(), id) >= REVOKE_RIGHTS, "Caller does not have enough rights");
        require(rightsOf(account, id) >= amount, "Not authorized");

        _balances[id][account].rights -= amount;
    }

    function setRights(address account, uint256 id, uint32 rights) public {
        uint64 callerRights = rightsOf(_msgSender(), id);
        uint64 targetRights = rightsOf(account, id);
        require(callerRights >= GRANT_RIGHTS, "Caller does not have enough rights");
        require(
            callerRights >= REVOKE_RIGHTS
            || targetRights < rights,
           "Caller does not have enough rights"
        );
        require(callerRights >= rights, "Callers rights cannot exceed granted rights");
        require(callerRights >= targetRights, "Cannot revoke rights from higher ranked accounts");
        _balances[id][account].rights = rights;

        emit SetRights(id, _msgSender(), account, rights);
    }

    function startProject(
        address owner,
        uint256 id,
        uint128 amount
    ) public {
        require(rightsOf(_msgSender(), 0) >= START_PROJECT, "Not enough rights to start a project");
        require(_activeProjects[id] == false, "Project id already exists");

        _activeProjects[id] = true;
        _mint(owner, id, amount, "");
        _balances[id][owner].rights = type(uint32).max;

        emit StartProject(owner, id, amount);
    }
}
