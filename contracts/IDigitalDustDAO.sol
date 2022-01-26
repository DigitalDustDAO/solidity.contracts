// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IDigitalDustDAO {
    event SetRights (
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint64 rights
    );

    event SetPenalty (
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint64 penalty
    );

    event StartProject (
        address indexed from,
        uint256 indexed id,
        uint128 amountMinted
    );

    function rightsOf(uint256 id, address account) external view returns (uint64 rights);

    function penaltyOf(uint256 id, address account) external view returns (uint64 penalty);

    function setPenalty(uint256 id, address account, uint64 penalty) external;

    function setRights(uint256 id, address account, uint64 rights) external;

    function startProject(uint256 id, uint128 amount, bytes memory data) external;
}