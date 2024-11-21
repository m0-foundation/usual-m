// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

/**
 * @title  NAV Proxy UsualM Chainlink Compatible Price Feed
 * @notice A proxy contract that retrieves NAV (Net Asset Value) data from an external oracle,
 *         converts it to a Usual M price based on a specified threshold, and is compatible with
 *         the Chainlink AggregatorV3Interface.
 * @author M^0 Labs
 */
contract NAVProxySmartMPriceFeed is AggregatorV3Interface {
    /// @notice NAV price threshold that defines 1$ UsualM price
    int256 public constant NAV_POSITIVE_THRESHOLD = 1e6;

    /// @notice The address of the NAV Oracle from which NAV data is fetched.
    address public immutable navOracle;

    /**
     * @notice Constructs the NAV Proxy UsualM Price Feed contract.
     * @param  navOracle_ The address of the NAV Oracle.
     */
    constructor(address navOracle_) {
        navOracle = navOracle_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() public pure returns (uint8) {
        return 6;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external pure returns (string memory) {
        return "M^0 NAV Proxy UsualM Price Feed";
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external pure returns (uint256) {
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

        // Convert NAV price to UsualM price given predefined threshold.
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
     * @dev Converts NAV price to UsualM price based on a predefined sensitivity threshold.
     * @param  answer The NAV price to convert.
     * @return        The UsualM price.
     */
    function _getPriceFromNAV(int256 answer) internal pure returns (int256) {
        return (answer >= NAV_POSITIVE_THRESHOLD) ? int256(10 ** decimals()) : answer;
    }
}
