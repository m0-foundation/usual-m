// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../../../lib/forge-std/src/Test.sol";

import { MockNavOracle } from "../../utils/Mocks.sol";

import { AggregatorV3Interface } from "../../../src/oracle/AggregatorV3Interface.sol";
import { NAVProxyMPriceFeed } from "../../../src/oracle/NAVProxyMPriceFeed.sol";

contract NAVProxyMPriceFeedUnitTests is Test {
    NAVProxyMPriceFeed public priceFeed;
    MockNavOracle public mockNavOracle;

    function setUp() public {
        mockNavOracle = new MockNavOracle();
        priceFeed = new NAVProxyMPriceFeed(address(mockNavOracle));
    }

    function test_constructor() external {
        assertEq(priceFeed.navOracle(), address(mockNavOracle));
        assertEq(priceFeed.decimals(), 8);
        assertEq(priceFeed.description(), "M by M^0 / USD");
        assertEq(priceFeed.version(), mockNavOracle.version());
    }

    function test_constructor_invalidDecimals() external {
        MockNavOracle invalidNavOracle = new MockNavOracle();
        vm.mockCall(
            address(invalidNavOracle),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(6) // Mock invalid decimals
        );

        vm.expectRevert(NAVProxyMPriceFeed.InvalidDecimalsNumber.selector);
        new NAVProxyMPriceFeed(address(invalidNavOracle));
    }

    function test_getRoundData() external {
        mockNavOracle.setRoundData(1, 2e8, block.timestamp - 100, block.timestamp, 1);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .getRoundData(1);

        assertEq(roundId, 1);
        assertEq(answer, 1e8); // Threshold applied
        assertEq(startedAt, block.timestamp - 100);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_latestRoundData_belowThreshold() external {
        mockNavOracle.setRoundData(2, 5e7, block.timestamp - 50, block.timestamp, 2);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .latestRoundData();

        assertEq(roundId, 2);
        assertEq(answer, 5e7); // No threshold applied
        assertEq(startedAt, block.timestamp - 50);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 2);
    }

    function test_latestRoundData_aboveThreshold() external {
        mockNavOracle.setRoundData(3, 1.5e8, block.timestamp - 30, block.timestamp, 3);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .latestRoundData();

        assertEq(roundId, 3);
        assertEq(answer, 1e8); // Threshold applied
        assertEq(startedAt, block.timestamp - 30);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 3);
    }
}
