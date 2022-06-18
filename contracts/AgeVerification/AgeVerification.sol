// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract AgeVerification is ERC20 {

    bytes32 private immutable AUTHORIZE_UNLOCK;
        
    constructor(bytes32 authorizeUnlock) ERC20("Maturity Token", "MATT") {
        AUTHORIZE_UNLOCK = authorizeUnlock;
    }

    function authorize(bytes memory proof) public {
        require(balanceOf(_msgSender()) == 0, "Already authorized");
        require(_msgSender() == _recoverSigner(AUTHORIZE_UNLOCK, proof), "Invalid signiture");
        
        _mint(_msgSender(), 10**decimals());
    }

    function unauthorize() public {
        require(balanceOf(_msgSender()) > 0, "Not authorized");

        _burn(_msgSender(), balanceOf(_msgSender()));
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("This token cannot be transfered");
    }

    function _recoverSigner(bytes32 message, bytes memory _signature) private pure returns (address) {
        require(_signature.length == 65, "Signature is invalid");

        bytes32 r; 
        bytes32 s;
        uint8 v;

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(_signature, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(_signature, 32))
            // second 32 bytes
            s := mload(add(_signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_signature, 96)))
        }

        return ecrecover(message, v, r, s);
    }
}
