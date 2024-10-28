// SPDX-License-Identifier: UNLICENSED

// TODO: Delete later,
// COPY from Usual repo https://github.com/usual-dao/pegasus/blob/develop/packages/solidity/src/registry/RegistryAccess.sol
pragma solidity 0.8.26;

import {
    AccessControlDefaultAdminRulesUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

import { IRegistryAccess } from "../../src/interfaces/IRegistryAccess.sol";

/// @notice  This contract is used to manage the access to function call
/// @title   RegistryAccess contract
/// @dev     We don't want all function to be called by anyone so we use this contract to manage the access
/// @author  Usual Tech team
contract RegistryAccess is AccessControlDefaultAdminRulesUpgradeable, IRegistryAccess {
    error NullAddress();
    error NotAuthorized();

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function for initializing the contract.
    /// @dev This function is used to set the initial state of the contract.
    /// @param deployer The deployer address.
    function initialize(address deployer) public initializer {
        // if the deployer address is null, revert the transaction
        if (deployer == address(0)) {
            revert NullAddress();
        }
        __AccessControl_init_unchained();
        __AccessControlDefaultAdminRules_init_unchained(
            3 days,
            deployer // Explicit initial `DEFAULT_ADMIN_ROLE` holder
        );
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized();
        }
        _setRoleAdmin(role, adminRole);
    }
}
