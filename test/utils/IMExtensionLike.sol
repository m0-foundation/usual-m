// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

interface IMExtensionLike {
    function wrap(address recipient, uint256 amount) external;

    function unwrap(address recipient, uint256 amount) external;
}
