// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { ERC1967Utils } from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import { Upgrades } from "../../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "../../lib/openzeppelin-foundry-upgrades/src/Options.sol";

import { UsualMV2 } from "../../src/usual/UsualMV2.sol";

abstract contract UpgradeUsualMBase is Script {
    address internal constant _USUAL_M_PROXY = 0x4Cbc25559DbBD1272EC5B64c7b5F48a2405e6470;
    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _USUAL_M_YIELD_RECIPIENT = 0x81ad394C0Fa87e99Ca46E1aca093BEe020f203f4;

    function _upgradeUsualM() internal {
        address proxyAdmin = _getAdminAddress(_USUAL_M_PROXY);
        console.log("Proxy Admin Address:", proxyAdmin);

        Options memory opts;
        opts.unsafeAllow = "missing-initializer";

        Upgrades.upgradeProxy(
            _USUAL_M_PROXY,
            "UsualMV2.sol:UsualMV2",
            abi.encodeCall(UsualMV2.initializeV2, (_M_TOKEN, _USUAL_M_YIELD_RECIPIENT)),
            opts,
            proxyAdmin
        );
    }

    function _getAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
