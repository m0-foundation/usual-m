// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { UsualM } from "../src/usual/UsualM.sol";

import {
    TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployUsualMScript is Script {
    address internal constant _WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291; // Mainnet Wrapped M

    address internal constant _USUAL_REGISTRY_ACCESS = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56; // Usual registry access

    address internal constant _USUAL_ADMIN = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7; // Usual default admin

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console2.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        address usualMImplementation = address(new UsualM());
        bytes memory usualMData = abi.encodeWithSignature(
            "initialize(address,address)",
            _WRAPPED_M_TOKEN,
            _USUAL_REGISTRY_ACCESS
        );
        address usualM = address(new TransparentUpgradeableProxy(usualMImplementation, _USUAL_ADMIN, usualMData));

        vm.stopBroadcast();

        console2.log("UsualM implementation:", usualMImplementation);
        console2.log("UsualM:", usualM);
    }
}
