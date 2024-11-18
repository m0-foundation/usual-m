// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

/**
 * @title  NAV Proxy SmartM Chainlink Compatible Price Feed
 * @notice A proxy contract that retrieves NAV (Net Asset Value) data from an external oracle,
 *         converts it to a Smart M price based on a specified threshold, and implements
 *         the Chainlink AggregatorV3Interface for compatibility.
 * @author M^0 Labs
 */
contract NAVProxySmartMPriceFeed is AggregatorV3Interface {
    /// @notice NAV price threshold that defines 1$ Smart M price
    int256 public constant NAV_POSITIVE_THRESHOLD = 1_100000;

    /// @notice The address of the NAV Oracle from which NAV data is fetched.
    address public immutable navOracle;

    /**
     * @notice Constructs the NAV Proxy Smart M Price Feed contract.
     * @param  navOracle_ The address of the NAV Oracle.
     */
    constructor(address navOracle_) {
        navOracle = navOracle_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() public view returns (uint8) {
        return 6;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external view returns (string memory) {
        return "NAV Proxy Smart M Price Feed";
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external view returns (uint256) {
        return 1;
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(
        uint80 roundId_
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = AggregatorV3Interface(navOracle).getRoundData(
            roundId_
        );

        // Convert NAV price to Smart M price given predefined threshold.
        answer = _getPriceFromNAV(answer);
    }

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = AggregatorV3Interface(navOracle).latestRoundData();

        // Convert NAV price to Smart M price given predefined threshold.
        answer = _getPriceFromNAV(answer);
    }

    /**
     * @dev Converts NAV price to Smart M price based on a predefined sensitivity threshold.
     * @param  answer The NAV price to convert.
     * @return        The Smart M price.
     */
    function _getPriceFromNAV(int256 answer) internal view returns (int256) {
        return (answer >= NAV_POSITIVE_THRESHOLD) ? int256(10 ** decimals()) : int256(0);
    }
}
