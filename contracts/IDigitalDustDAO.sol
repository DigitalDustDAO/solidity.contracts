// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IDigitalDustDAO {
    // TODO: define events here

    function rightsOf(uint256 id, address account) external view returns (uint64 rights);

    function penaltyOf(uint256 id, address account) external view returns (uint64 penalty);

    function setPenalty(uint256 id, address account, uint64 penalty) external;

    function setRights(uint256 id, address account, uint64 rights) external;
}