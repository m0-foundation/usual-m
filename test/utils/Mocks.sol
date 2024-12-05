// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockWrappedM {
    mapping(address account => uint256 balance) public balanceOf;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {}

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        return true;
    }

    function setBalanceOf(address account, uint256 balance) external {
        balanceOf[account] = balance;
    }
}

contract MockRegistryAccess {
    mapping(bytes32 role => mapping(address account => bool status)) internal _roles;

    function grantRole(bytes32 role, address account) external {
        _roles[role][account] = true;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }
}

contract MockNavOracle {
    uint8 public immutable decimals = 8;
    string public constant description = "Mock NAV Oracle";
    uint256 public immutable version = 1;

    int256 internal _navPrice;
    uint80 internal _roundId;
    uint256 internal _startedAt;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;

    function setRoundData(
        uint80 roundId,
        int256 navPrice,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _navPrice = navPrice;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function getRoundData(uint80) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, _navPrice, _startedAt, _updatedAt, _answeredInRound);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, _navPrice, _startedAt, _updatedAt, _answeredInRound);
    }
}
