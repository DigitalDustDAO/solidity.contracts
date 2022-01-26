// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISocialTokenNFT {
    
    function interestBonus(address account) external returns(uint64);

}