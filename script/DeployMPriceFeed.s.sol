// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { NAVProxyMPriceFeed } from "../src/oracle/NAVProxyMPriceFeed.sol";

contract DeployMPriceFeedScript is Script {
    address internal constant _CHAINLINK_NAV_ORACLE = 0xC28198Df9aee1c4990994B35ff51eFA4C769e534; // Mainnet M^0 Chainlink NAV oracle

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console2.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        address priceFeed = address(new NAVProxyMPriceFeed(_CHAINLINK_NAV_ORACLE));

        vm.stopBroadcast();

        console2.log("price feed:", priceFeed);
    }
}
