// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV3Interface {
    /// @notice Gets the number of decimals used by the aggregator.
    function decimals() external view returns (uint8);

    /// @notice Get the description of the aggregator.
    function description() external view returns (string memory);

    /// @notice Get the version of the aggregator.
    function version() external view returns (uint256);

    /// @notice Gets the round data for a specific round ID.
    function getRoundData(
        uint80 roundId_
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /// Gets the latest round data.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
