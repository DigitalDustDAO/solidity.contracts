// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IDigitalDustDAO {
    event SetRights (
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint128 rights
    );

    event SetPenalty (
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint128 penalty
    );

    event StartProject (
        address indexed from,
        uint256 indexed id,
        uint256 amountMinted
    );

    struct Access {
        uint128 rights;
        uint128 penalty;
    }

    function rightsOf(address account, uint256 id) external view returns (uint128 rights);
    function penaltyOf(address account, uint256 id) external view returns (uint128 penalty);
    function accessOf(address account, uint256 id) external view returns (uint128 access);
    function consumeAccess(address account, uint256 id, uint128 amount) external returns (uint128 access);
    function setPenalty(address account, uint256 id, uint128 penalty) external;
    function setRights(address account, uint256 id, uint128 rights) external;
    function startProject(address owner, uint256 id, uint256 amount) external;
}
