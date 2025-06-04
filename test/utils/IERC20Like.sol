// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

interface IERC20Like {
    event Transfer(address indexed from, address indexed to, uint256 value);
    function balanceOf(address account) external view returns (uint256 balance);
}
