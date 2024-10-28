// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {
    IAccessControlDefaultAdminRules
} from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

// solhint-disable-next-line no-empty-blocks
interface IRegistryAccess is IAccessControlDefaultAdminRules {}
