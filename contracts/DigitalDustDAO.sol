pragma solidity ^0.8;

import "./ERC1155WithAccess.sol";

contract DigitalDustDAO is ERC1155WithAccess {
    uint64 constant private GRANT_RIGHTS = 100;
    uint64 constant private REVOKE_RIGHTS = 400;
    uint64 constant private APPLY_PENALTY = 400;
    uint64 constant private START_PROJECT = 400;

    mapping(uint256 => boolean) private _activeProjects;

    constructor() ERC1155WithAccess("") {
        _balances[0][_msgSender()].rights = 500;
    }

    function rightsOf(uint256 id, address account) public view returns (uint64 rights) {
        return _balances[0][account].rights > _balances[id][account].rights
            ? _balances[0][account].rights
            : _balances[id][account].rights;
    }

    function penaltyOf(uint256 id, address account) public view returns (uint64 penalty) {
        return _balances[0][account].penalty > _balances[id][account].penalty
            ? _balances[0][account].penalty
            : _balances[id][account].penalty;
    }

    function setPenalty(uint256 id, address account, uint64 penalty) public {
        require(rightsOf(id, _msgSender()) >= APPLY_PENALTY, "Not enough rights to set penalty");
        _balances[id][account].penalty = penalty;
    }

    function setRights(uint256 id, address account, uint64 rights) public {
        uint64 memory callerRights = rightsOf(id, _msgSender());
        require(callerRights >= GRANT_RIGHTS, "Not enough rights to grant rights");
        require(
            callerRights < REVOKE_RIGHTS
            && rightsOf(id, account) > rights,
            "Not enough rights to revoke rights"
        );
        require(callerRights >= rights, "Callers rights cannot exceed granted rights");
        _balances[id][account].rights = rights;
    }

    function startProject(
        uint256 id,
        uint128 amount,
        bytes memory data
    ) internal {
        require(rightsOf(0, _msgSender() >= START_PROJECT), "Not enough rights to start a project");
        require(_activeProjects[id] == false, "Project id already exists");

        _activeProjects[id] = true;
        _mint(_msgSender(), id, amount, data);
    }
}
