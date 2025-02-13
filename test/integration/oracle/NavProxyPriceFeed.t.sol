// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../../../lib/forge-std/src/Test.sol";

import { NAVProxyMPriceFeed } from "../../../src/oracle/NAVProxyMPriceFeed.sol";

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract NAVProxyMPriceFeedIntegrationTests is Test {
    NAVProxyMPriceFeed public priceFeed;
    IPyth public pyth;
    bytes32 public priceId;
    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        pyth = IPyth(0x4305FB66699C3B2702D4d05CF36551390A4c69C6);
        priceId = bytes32(0x967549f1ff4869f41cb354a7116b9e5a9a3091bebe0b2640eeed745ca1f7f90b);

        priceFeed = new NAVProxyMPriceFeed(address(pyth), priceId);
    }

    function test_latestRoundData() public {
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        console2.log("roundId", roundId);
        console2.log("price", price);
        console2.log("startedAt", startedAt);
        console2.log("updatedAt", updatedAt);
        console2.log("answeredInRound", answeredInRound);
        vm.stopPrank();
    }
}