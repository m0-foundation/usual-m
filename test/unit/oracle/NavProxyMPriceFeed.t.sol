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

    function test_constructor() external view {
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
        uint256 currentTimestamp = block.timestamp;
        mockNavOracle.setRoundData(1, 2e8, currentTimestamp > 100 ? currentTimestamp - 100 : 0, currentTimestamp, 1);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .getRoundData(1);

        assertEq(roundId, 1);
        assertEq(answer, 1e8); // Threshold applied
        assertEq(startedAt, currentTimestamp > 100 ? currentTimestamp - 100 : 0);
        assertEq(updatedAt, currentTimestamp);
        assertEq(answeredInRound, 1);
    }

    function test_latestRoundData_belowThreshold() external {
        uint256 currentTimestamp = block.timestamp;
        mockNavOracle.setRoundData(2, 5e7, currentTimestamp > 50 ? currentTimestamp - 50 : 0, currentTimestamp, 2);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .latestRoundData();

        assertEq(roundId, 2);
        assertEq(answer, 5e7); // No threshold applied
        assertEq(startedAt, currentTimestamp > 50 ? currentTimestamp - 50 : 0);
        assertEq(updatedAt, currentTimestamp);
        assertEq(answeredInRound, 2);
    }

    function test_latestRoundData_aboveThreshold() external {
        uint256 currentTimestamp = block.timestamp;
        mockNavOracle.setRoundData(3, 1.5e8, currentTimestamp > 30 ? currentTimestamp - 30 : 0, currentTimestamp, 3);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed
            .latestRoundData();

        assertEq(roundId, 3);
        assertEq(answer, 1e8); // Threshold applied
        assertEq(startedAt, currentTimestamp > 30 ? currentTimestamp - 30 : 0);
        assertEq(updatedAt, currentTimestamp);
        assertEq(answeredInRound, 3);
    }

    function testFuzz_priceConversion(int256 price) external {
        price = bound(price, 0, 1e36);

        uint8[3] memory decimalConfigs = [6, 8, 18];

        for (uint256 i = 0; i < decimalConfigs.length; i++) {
            uint8 oracleDecimals = decimalConfigs[i];
            MockNavOracle testOracle = new MockNavOracle();

            // Mock decimals to 8 for constructor
            vm.mockCall(
                address(testOracle),
                abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
                abi.encode(8)
            );

            NAVProxyMPriceFeed testFeed = new NAVProxyMPriceFeed(address(testOracle));

            // Change mocked decimals for testing
            vm.mockCall(
                address(testOracle),
                abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
                abi.encode(oracleDecimals)
            );

            testOracle.setRoundData(1, price, block.timestamp, block.timestamp, 1);

            (, int256 answer, , , ) = testFeed.latestRoundData();

            // Output needs to be n 8 decimals
            assertEq(testFeed.decimals(), 8);

            // Price is capped at $1
            assertTrue(answer <= 1e8, "Price should never exceed $1 in 8 decimals");

            int256 scaledAnswer = (price * 1e8) / int256((10 ** oracleDecimals));

            if (scaledAnswer < 1e8) {
                assertEq(answer, scaledAnswer, "Price below $1 should maintain value after decimal conversion");
            }

            if (scaledAnswer >= 1e8) {
                assertEq(answer, 1e8, "Price above $1 should be capped at $1");
            }
        }
    }

    function testFuzz_priceConversionNegativeValues(int256 price) external {
        price = bound(price, -1e36, 0);

        MockNavOracle testOracle = new MockNavOracle();
        testOracle.setRoundData(1, price, block.timestamp, block.timestamp, 1);

        NAVProxyMPriceFeed testFeed = new NAVProxyMPriceFeed(address(testOracle));

        (, int256 answer, , , ) = testFeed.latestRoundData();

        // Verify properties:
        //  Negative prices should remain negative
        assertTrue(answer <= 0, "Negative prices should remain negative");

        // 2. No capping for negative values
        assertEq(
            answer,
            (price * int256(1e8)) / int256(10 ** testOracle.decimals()),
            "Negative prices should maintain"
        );
    }
}
