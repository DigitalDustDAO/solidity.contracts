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

        emit SetRights(0, address(0), _msgSender(), type(uint32).max);
    }

    function rightsOf(uint256 id, address account) external view returns (uint64 rights) {
        return _balances[0][account].rights > _balances[id][account].rights
            ? _balances[0][account].rights
            : _balances[id][account].rights;
    }

    function penaltyOf(uint256 id, address account) external view returns (uint64 penalty) {
        return _balances[0][account].penalty > _balances[id][account].penalty
            ? _balances[0][account].penalty
            : _balances[id][account].penalty;
    }

    function accessOf(uint256 id, address account) external view returns (uint64 access) {
        return _balances[0][account].rights - _balances[0][account].penalty > _balances[id][account].rights - _balances[id][account].penalty
            ? _balances[0][account].rights - _balances[0][account].penalty
            : _balances[id][account].rights - _balances[id][account].penalty;
    }

    function setPenalty(uint256 id, address account, uint32 penalty) external {
        require(this.rightsOf(id, _msgSender()) >= APPLY_PENALTY, "Not enough rights to set penalty");
        _balances[id][account].penalty = penalty;

        emit SetPenalty(id, _msgSender(), account, penalty);
    }

    function setRights(uint256 id, address account, uint32 rights) external {
        uint64 callerRights = this.rightsOf(id, _msgSender());
        uint64 targetRights = this.rightsOf(id, account);
        require(callerRights >= GRANT_RIGHTS, "Not enough rights to grant rights");
        require(
            callerRights >= REVOKE_RIGHTS
            || targetRights < rights,
            "Not enough rights to revoke rights"
        );
        require(callerRights >= rights, "Callers rights cannot exceed granted rights");
        require(callerRights >= targetRights, "Cannot revoke rights from higher ranked accounts");
        _balances[id][account].rights = rights;

        emit SetRights(id, _msgSender(), account, rights);
    }

    function startProject(
        uint256 id,
        uint128 amount,
        bytes memory data
    ) external {
        require(this.rightsOf(0, _msgSender()) >= START_PROJECT, "Not enough rights to start a project");
        require(_activeProjects[id] == false, "Project id already exists");

        _activeProjects[id] = true;
        _mint(_msgSender(), id, amount, data);

        emit StartProject(_msgSender(), id, amount);
    }
}
