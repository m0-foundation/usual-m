// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

interface IRegistrarLike {
    function addToList(bytes32 list, address account) external;

    function removeFromList(bytes32 list, address account) external;

    function setKey(bytes32 key, bytes32 value) external;
}
