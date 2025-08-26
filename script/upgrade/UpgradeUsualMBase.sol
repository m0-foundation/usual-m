// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { Upgrades } from "../../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "../../lib/openzeppelin-foundry-upgrades/src/Options.sol";

import { UsualMV2 } from "../../src/usual/UsualMV2.sol";

abstract contract UpgradeUsualMBase is Script {
    address internal constant _USUAL_M_PROXY = 0x4Cbc25559DbBD1272EC5B64c7b5F48a2405e6470;
    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;
    address internal constant _USUAL_M_YIELD_RECIPIENT = 0x81ad394C0Fa87e99Ca46E1aca093BEe020f203f4;

    function _upgradeUsualM() internal {
        address proxyAdmin = _getAdminAddress(_USUAL_M_PROXY);
        console.log("Proxy Admin Address:", proxyAdmin);

        Options memory opts;
        opts.unsafeAllow = "missing-initializer";

        Upgrades.upgradeProxy(_USUAL_M_PROXY, "UsualMV2.sol:UsualMV2", _getInitializeV2Calldata(), opts, proxyAdmin);
    }

    /// @dev Deploys the new UsualMV2 implementation and returns its address.
    function _prepareUsualMUpgrade() internal returns (address) {
        Options memory opts;
        opts.unsafeAllow = "missing-initializer";

        return Upgrades.prepareUpgrade("UsualMV2.sol:UsualMV2", opts);
    }

    function _getAdminAddress(address proxy) internal view returns (address) {
        return Upgrades.getAdminAddress(proxy);
    }

    function _getInitializeV2Calldata() internal pure returns (bytes memory) {
        return abi.encodeCall(UsualMV2.initializeV2, (_M_TOKEN, _SWAP_FACILITY, _USUAL_M_YIELD_RECIPIENT));
    }

    function _getUpgradeAndCallCalldata(address implementation) internal pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "upgradeAndCall(address,address,bytes)",
                _USUAL_M_PROXY,
                implementation,
                _getInitializeV2Calldata()
            );
    }
}
