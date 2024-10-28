// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UCToken } from "../../src/UCToken.sol";

contract UCTokenHarness is UCToken {
    function internalWrap(address account, address recipient, uint256 amount) external returns (uint256) {
        return _wrap(account, recipient, amount);
    }

    function internalUnwrap(address account, address recipient, uint256 amount) external returns (uint256) {
        return _unwrap(account, recipient, amount);
    }
}
