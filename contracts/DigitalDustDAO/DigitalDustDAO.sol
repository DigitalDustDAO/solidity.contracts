// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";

contract DigitalDustDAO is IDigitalDustDAO, Context, ERC1155 {
    uint128 constant private GRANT_RIGHTS  = 200;
    uint128 constant private REVOKE_RIGHTS = 400;
    uint128 constant private APPLY_PENALTY = 400;
    uint128 constant private START_PROJECT = 500;

    string private INSUFFICIENT_RIGHTS = "Caller does not have enough rights";

    mapping(uint256 => mapping(address => Access)) private access;
    mapping(uint256 => uint256) private projectShareTotals;

    constructor(uint256 levelZeroTokensToMint) ERC1155("") {
        access[0][_msgSender()].rights = type(uint128).max;
        projectShareTotals[0] = levelZeroTokensToMint;
        _mint(_msgSender(), 0, levelZeroTokensToMint, "");

        emit SetRights(0, address(0), _msgSender(), type(uint128).max);
    }

    function rightsOf(address account, uint256 id) public view returns (uint128) {
        return access[id][account].rights;
    }

    function penaltyOf(address account, uint256 id) public view returns (uint128) {
        return access[id][account].penalty;
    }

    function accessOf(address account, uint256 id) public view returns (uint128) {
        unchecked {
            return access[id][account].rights <= access[id][account].penalty ? 0 : 
                access[id][account].rights - access[id][account].penalty;
        }
    }

    function getProjectStarted(uint256 id) public view returns(bool) {
        return projectShareTotals[id] > 0;
    }

    function getProjectTotalShares(uint256 id) public view returns(uint256) {
        return projectShareTotals[id];
    }

    function setPenalty(address account, uint256 id, uint128 penalty) public {
        require(rightsOf(_msgSender(), id) >= APPLY_PENALTY, INSUFFICIENT_RIGHTS);
        access[id][account].penalty = penalty;

        emit SetPenalty(id, _msgSender(), account, penalty);
    }

    function setBulkPenalty(address[] memory accounts, uint256 id, uint128 penalty) public {
        require(rightsOf(_msgSender(), id) >= APPLY_PENALTY, INSUFFICIENT_RIGHTS);
 
        for (uint i = 0;i < accounts.length;i++) {
            access[id][accounts[i]].penalty = penalty;
            emit SetPenalty(id, _msgSender(), accounts[i], penalty);
        }
    }

    function migrateAccess(address[] memory accounts, uint256 sourceProjectId, uint256 destProjectId) public {
        require(access[sourceProjectId][_msgSender()].rights >= START_PROJECT 
            && access[destProjectId][_msgSender()].rights >= START_PROJECT, INSUFFICIENT_RIGHTS);

        for (uint i = 0;i < accounts.length;i++) {
            if (access[sourceProjectId][accounts[i]].rights > access[destProjectId][accounts[i]].rights) {
                access[destProjectId][accounts[i]] = access[sourceProjectId][accounts[i]];
                emit SetRights(destProjectId, _msgSender(), accounts[i], access[destProjectId][accounts[i]].rights);
            }
        }
    }

    function consumeAccess(address account, uint256 id, uint128 amount) external returns(uint128) {
        require(rightsOf(_msgSender(), id) >= REVOKE_RIGHTS, INSUFFICIENT_RIGHTS);
        require(rightsOf(account, id) >= amount && rightsOf(account, id) <= 100, "Not authorized");

        access[id][account].rights -= amount;
        emit SetRights(id, _msgSender(), account, access[id][account].rights);

        return access[id][account].rights;
    }

    function setRights(address account, uint256 id, uint128 rights) public {
        uint128 callerRights = rightsOf(_msgSender(), id);
        uint128 targetRights = rightsOf(account, id);
        require(callerRights >= GRANT_RIGHTS, INSUFFICIENT_RIGHTS);
        require(callerRights >= REVOKE_RIGHTS || targetRights < rights, INSUFFICIENT_RIGHTS);
        require(callerRights >= rights || _msgSender() == account, "Callers rights cannot exceed granted rights");
        require(callerRights >= targetRights || _msgSender() == account, "Cannot revoke rights from higher ranked accounts");
        
        access[id][account].rights = rights;

        emit SetRights(id, _msgSender(), account, rights);
    }

    function setBulkRights(address[] memory accounts, uint256 id, uint128 rights) public {
        uint128 callerRights = rightsOf(_msgSender(), id);
        require(callerRights >= GRANT_RIGHTS, INSUFFICIENT_RIGHTS);
        require(callerRights >= rights, "Callers rights cannot exceed granted rights");

        uint128 targetRights;
        for (uint i = 0;i < accounts.length;i++) {
            targetRights = rightsOf(accounts[i], id);
            if ((targetRights < rights || callerRights >= REVOKE_RIGHTS) && callerRights >= targetRights) {
                access[id][accounts[i]].rights = rights;

                emit SetRights(id, _msgSender(), accounts[i], rights);
            }
        }
    }

    function setProjectUri(string memory newUri) public {
        require(rightsOf(_msgSender(), 0) >= START_PROJECT, INSUFFICIENT_RIGHTS);

        _setURI(newUri);
    }

    function startProject(
        address owner,
        uint256 id,
        uint256 amount
    ) public {
        require(rightsOf(_msgSender(), 0) >= START_PROJECT, INSUFFICIENT_RIGHTS);
        require(amount > 0, "Must mint at least one project coin");
        require(projectShareTotals[id] == 0, "Project id in use");

        projectShareTotals[id] = amount;
        _mint(owner, id, amount, "");
        access[id][owner].rights = type(uint128).max;

        emit StartProject(owner, id, amount);
    }
}
