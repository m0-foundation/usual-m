// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { UpgradeUsualMBase } from "./UpgradeUsualMBase.sol";

contract UpgradeUsualM is UpgradeUsualMBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        _upgradeUsualM();

        vm.stopBroadcast();

        console.log("UsualM upgraded successfully.");
    }
}
