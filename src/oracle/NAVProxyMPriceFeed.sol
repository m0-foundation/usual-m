// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

/**
 * @title  NAV Proxy M Chainlink Compatible Price Feed
 * @notice A proxy contract that retrieves NAV (Net Asset Value) data from an external oracle,
 *         converts it to a M price based on a specified threshold, and is compatible with
 *         the Chainlink AggregatorV3Interface.
 * @author M^0 Labs
 */
contract NAVProxyMPriceFeed is AggregatorV3Interface {
    /// @notice Emitted when NAV oracle has invalid decimals number.
    error InvalidDecimalsNumber();

    /// @notice NAV price threshold that defines 1$ M price.
    int256 public constant NAV_POSITIVE_THRESHOLD = 1e8;

    /// @notice The address of the NAV Oracle from which NAV data is fetched.
    address public immutable navOracle;

    /**
     * @notice Constructs the NAV Proxy M Price Feed contract.
     * @param  navOracle_ The address of the NAV Oracle.
     */
    constructor(address navOracle_) {
        if (AggregatorV3Interface(navOracle_).decimals() != 8) revert InvalidDecimalsNumber();

        navOracle = navOracle_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() public pure returns (uint8) {
        return 8;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external pure returns (string memory) {
        return "M by M^0 / USD";
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external view returns (uint256) {
        return AggregatorV3Interface(navOracle).version();
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

        // Convert NAV price to M price given predefined threshold.
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
     * @dev Converts NAV price to M price based on a predefined sensitivity threshold.
     * @param  answer The NAV price to convert.
     * @return        The M price.
     */
    function _getPriceFromNAV(int256 answer) internal pure returns (int256) {
        return answer >= NAV_POSITIVE_THRESHOLD ? NAV_POSITIVE_THRESHOLD : answer;
    }
}
