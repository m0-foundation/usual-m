// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { UpgradeUsualMBase } from "./UpgradeUsualMBase.sol";

contract PrepareUsualMUpgrade is UpgradeUsualMBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        address usualMV2Implementation_ = _prepareUsualMUpgrade();

        vm.stopBroadcast();

        console.log("UsualMV2 Implementation successfully deployed at: %s", usualMV2Implementation_);

        console.log("Calldata to initialize the new implementation:");
        console.logBytes(_getInitializeV2Calldata());

        console.log("Proxy admin to call to perform the upgrade: %s", _getAdminAddress(_USUAL_M_PROXY));

        console.log("Calldata to call the proxy admin with to perform the upgrade:");
        console.logBytes(_getUpgradeAndCallCalldata(usualMV2Implementation_));
    }
}
