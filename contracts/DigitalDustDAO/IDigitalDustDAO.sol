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

    function rightsOf(address account, uint256 id) external view returns (uint32 rights);
    function penaltyOf(address account, uint256 id) external view returns (uint32 penalty);
    function accessOf(address account, uint256 id) external view returns (uint32 access);
    function setPenalty(address account, uint256 id, uint32 penalty) external;
    function setRights(address account, uint256 id, uint32 rights) external;
    function startProject(address owner, uint256 id, uint128 amount) external;
    function consumeAccess(address account, uint256 id, uint32 amount) external;
}
