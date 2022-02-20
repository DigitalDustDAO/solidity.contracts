// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../DigitalDustDAO/IDigitalDustDAO.sol";
import "./IMeasureManager.sol";
import "./IMeasure.sol";
import "./IRule34.sol";

contract BootstrapManager is Context, IMeasureManager, ERC165 {
    IDigitalDustDAO daoContract;
    IRule34 private rule34Contract;
    IMeasure private measureContract;
    address private maleContract;
    address private famaleContract;

    uint256 daoId;

    string constant private UNAUTHORIZED = "Not authorized";
    string constant private INVALID_INTERFACE = "Invalid interface";
    bool private initialized;

    constructor(address dao_, uint256 daoId_) {
        daoContract = IDigitalDustDAO(dao_);
        daoId = daoId_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IMeasureManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function initialize(address measureContract_, address maleContract_, address famaleContract_, address rule34Contract_) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        
        measureContract = IMeasure(measureContract_);
        maleContract = maleContract_;
        famaleContract = famaleContract_;
        rule34Contract = IRule34(rule34Contract);

        initialized = true;
    }

    // Time to pass to a new manager
    function upgrade(address newManager, address payable sendTo) public {
        this.authorize(_msgSender(), Sensitivity.Elder);
        require(initialized);
        require(IMeasureManager(newManager).supportsInterface(type(IMeasureManager).interfaceId), INVALID_INTERFACE);

        rule34Contract.setManager(newManager);
        measureContract.setManager(newManager);

        initialized = false;
        selfdestruct(sendTo);
    }

    function getRule34Contract() public view returns(IRule34) {
        require(initialized);
        return rule34Contract;
    }

    function authorize(address account, Sensitivity level) external view {
        if (level == Sensitivity.Council) {
            require(daoContract.accessOf(daoId, account) >= 400, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Elder) {
            require(daoContract.accessOf(daoId, account) >= 500, UNAUTHORIZED);
        }
        else if (level == Sensitivity.TokenWrapper) {
            require(account == maleContract || account == famaleContract, UNAUTHORIZED);
        }
        else if (level == Sensitivity.Rule34) {
            require(account == address(rule34Contract), UNAUTHORIZED);
        }
        else { // invalid input, deny
            revert(UNAUTHORIZED);
        }
    }

    function adjustInterest() external view {
        // not implemented in this version
    }
}
