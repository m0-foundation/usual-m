// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { UCToken } from "../src/token/UCToken.sol";

import {
    TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployScript is Script {
    address internal constant _SMART_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291; // Mainnet Smart M

    address internal constant _USUAL_REGISTRY_ACCESS = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56; // Usual registry access

    address internal constant _USUAL_ADMIN = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7; // Usual default admin

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console2.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        address ucTokenImplementation = address(new UCToken());
        bytes memory ucTokenData = abi.encodeWithSignature(
            "initialize(address,address)",
            address(_SMART_M_TOKEN),
            _USUAL_REGISTRY_ACCESS
        );
        address ucToken = address(new TransparentUpgradeableProxy(ucTokenImplementation, _USUAL_ADMIN, ucTokenData));

        vm.stopBroadcast();

        console2.log("UCToken implementation:", ucTokenImplementation);
        console2.log("UCToken:", ucToken);
    }
}
