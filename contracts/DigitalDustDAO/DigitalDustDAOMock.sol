// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./DigitalDustDAO.sol";

contract DigitalDustDAOMock is DigitalDustDAO {
    mapping(uint256 => mapping(address => MemberBalance)) internal _balances;
    mapping(uint256 => bool) internal _activeProjects;

    function getProject(uint256 id) external view returns (bool) {
        return _activeProjects[id];
    }
}
