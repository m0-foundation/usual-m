// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

import { wMXL } from "src/wmxl/wMXL.sol";
import { RegistryAccess } from "src/access/RegistryAccess.sol";
import { WrappedMToken } from "wrapped-m-token/src/WrappedMToken.sol";

import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeploywMXLScript is Script {
    address internal constant _M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291; // Mainnet M Token
    address internal constant _USUAL_ADMIN = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7; // Usual default admin

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        // Deploy Wrapped M Token implementation
        address wrappedMImplementation = address(new WrappedMToken(_M_TOKEN, _USUAL_ADMIN));
        
        // Deploy Wrapped M Token proxy
        address wrappedMAddress = address(new TransparentUpgradeableProxy(wrappedMImplementation, _USUAL_ADMIN, ""));

        // Deploy RegistryAccess implementation
        address registryAccessImplementation = address(new RegistryAccess());
        
        // Deploy RegistryAccess proxy and initialize
        bytes memory registryAccessData = abi.encodeWithSignature(
            "initialize(address)",
            _USUAL_ADMIN
        );
        address registryAccessAddress = address(new TransparentUpgradeableProxy(registryAccessImplementation, _USUAL_ADMIN, registryAccessData));

        // Deploy wMXL implementation
        address wMXLImplementation = address(new wMXL());
        
        // Deploy wMXL proxy and initialize with the deployed registry access
        bytes memory wMXLData = abi.encodeWithSignature(
            "initialize(address,address)",
            wrappedMAddress,
            registryAccessAddress
        );
        address(new TransparentUpgradeableProxy(wMXLImplementation, _USUAL_ADMIN, wMXLData));

        vm.stopBroadcast();
    }
}
