// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../lib/forge-std/src/Test.sol";

import { Pausable } from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

import { IUCToken } from "../src/interfaces/IUCToken.sol";

import { MockM } from "./utils/Mocks.sol";
import { UCTokenHarness } from "./utils/UCTokenHarness.sol";
import { RegistryAccess } from "./utils/RegistryAccess.sol";

import { UCT_UNWRAP, UCT_PAUSE_UNPAUSE } from "../src/constants.sol";

contract UCTokenTests is Test {
    uint256 internal constant _EXP_SCALED_ONE = 1e12;

    address internal _treasury = makeAddr("treasury");

    address internal _admin = makeAddr("admin");
    address internal _pauser = makeAddr("pauser");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _david = makeAddr("david");

    address internal _other = makeAddr("other");

    address[] internal _accounts = [_alice, _bob, _charlie, _david];

    MockM internal _mToken;
    UCTokenHarness internal _ucToken;
    RegistryAccess internal _registryAccess;

    function setUp() external {
        _mToken = new MockM();
        _mToken.setCurrentIndex(uint128(_EXP_SCALED_ONE));

        _registryAccess = new RegistryAccess();
        _resetInitializerImplementation(address(_registryAccess));
        _registryAccess.initialize(_admin);

        _ucToken = new UCTokenHarness();
        _resetInitializerImplementation(address(_ucToken));
        _ucToken.initialize(address(_mToken), address(_registryAccess), _treasury);

        // Set pauser/unpauser role
        vm.prank(_admin);
        _registryAccess.grantRole(UCT_PAUSE_UNPAUSE, _pauser);

        // Allow accounts to unwrap and fund with $M
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _mToken.setBalanceOf(_accounts[i], 10e6);

            vm.prank(_admin);
            _registryAccess.grantRole(UCT_UNWRAP, _accounts[i]);
        }

        vm.prank(_treasury);
        _mToken.approve(_treasury, type(uint256).max);

        // _mToken.setCurrentIndex(_currentIndex = 1_100000068703);
    }

    /* ============ initialization ============ */
    function test_init() external view {
        assertEq(_ucToken.mToken(), address(_mToken));
        assertEq(_ucToken.registryAccess(), address(_registryAccess));
        assertEq(_ucToken.treasury(), _treasury);
        assertEq(_ucToken.name(), "UCToken");
        assertEq(_ucToken.symbol(), "UCT");
        assertEq(_ucToken.decimals(), 6);
    }

    /* ============ wrap ============ */
    function test_wrap_wholeBalance() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(_treasury), 10e6);

        assertEq(_ucToken.balanceOf(_alice), 10e6);
    }

    function test_wrap() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(_treasury), 5e6);

        assertEq(_ucToken.balanceOf(_alice), 5e6);
    }

    function test_wrapWithPermit() external {
        vm.prank(_bob);
        _ucToken.wrapWithPermit(_alice, 5e6, 0, 0, bytes32(0), bytes32(0));

        assertEq(_mToken.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(_treasury), 5e6);

        assertEq(_ucToken.balanceOf(_bob), 0);
    }

    /* ============ unwrap ============ */

    function test_unwrap() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_alice);
        _ucToken.unwrap(_alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(_treasury), 5e6);

        assertEq(_ucToken.balanceOf(_alice), 5e6);
    }

    function test_unwrap_wholeBalance() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_alice);
        _ucToken.unwrap(_alice);

        assertEq(_mToken.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(_treasury), 0);

        assertEq(_ucToken.balanceOf(_alice), 0);
    }

    function test_unwarp_notAllowed() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.unwrap(_other, 5e6);
    }

    function test_unwarp_wholeBalance_notAllowed() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.unwrap(_other);
    }

    /* ============ pause ============ */
    function test_pause_wrap() external {
        vm.prank(_pauser);
        _ucToken.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);
    }

    function test_pause_transfer() external {
        vm.prank(_pauser);
        _ucToken.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _ucToken.transfer(_bob, 5e6);
    }

    function test_pause_unwrap() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice);

        vm.prank(_pauser);
        _ucToken.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _ucToken.unwrap(_bob);
    }

    function test_pause_unauthorized() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.pause();
    }

    function test_unpause_unathorized() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.unpause();
    }

    /* ============ blacklist ============ */
    function test_blacklisted_wrap() external {
        assertEq(_ucToken.isBlacklisted(_alice), false);

        vm.prank(_admin);
        _ucToken.blacklist(_alice);

        assertEq(_ucToken.isBlacklisted(_alice), true);

        vm.expectRevert(IUCToken.Blacklisted.selector);

        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);
    }

    function test_blacklisted_unwrap() external {
        assertEq(_ucToken.isBlacklisted(_alice), false);

        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_admin);
        _ucToken.blacklist(_alice);

        assertEq(_ucToken.isBlacklisted(_alice), true);

        vm.expectRevert(IUCToken.Blacklisted.selector);

        vm.prank(_alice);
        _ucToken.unwrap(_alice, 10e6);
    }

    function test_blacklisted_transfer() external {
        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_admin);
        _ucToken.blacklist(_alice);

        vm.expectRevert(IUCToken.Blacklisted.selector);

        vm.prank(_alice);
        _ucToken.transfer(_bob, 10e6);
    }

    function test_blacklist_unauthorized() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.blacklist(_alice);
    }

    function test_unBlacklist_unauthorized() external {
        vm.expectRevert(IUCToken.NotAuthorized.selector);

        vm.prank(_other);
        _ucToken.unBlacklist(_alice);
    }

    function test_blacklist_unBlacklist() external {
        vm.prank(_admin);
        _ucToken.blacklist(_alice);

        assertEq(_ucToken.isBlacklisted(_alice), true);

        vm.expectRevert(IUCToken.Blacklisted.selector);

        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_admin);
        _ucToken.unBlacklist(_alice);

        vm.prank(_alice);
        uint256 res = _ucToken.wrap(_alice, 10e6);
        assertEq(res, 10e6);

        assertEq(_ucToken.isBlacklisted(_alice), false);
    }

    function test_blacklist_zeroAddress() external {
        vm.expectRevert(IUCToken.ZeroAddress.selector);

        vm.prank(_admin);
        _ucToken.blacklist(address(0));
    }

    function test_unBlacklist_zeroAddress() external {
        vm.expectRevert(IUCToken.ZeroAddress.selector);

        vm.prank(_admin);
        _ucToken.unBlacklist(address(0));
    }

    /* ============ yield ============ */
    function test_totalAccruedYield() external {
        assertEq(_ucToken.totalAccruedYield(), 0);

        vm.prank(_treasury);
        _mToken.startEarning();

        vm.prank(_alice);
        _ucToken.wrap(_alice, 10e6);

        vm.prank(_bob);
        _ucToken.wrap(_bob, 10e6);

        assertEq(_ucToken.totalAccruedYield(), 0);

        _mToken.setCurrentIndex(11e11);

        assertEq(_ucToken.totalAccruedYield(), 2e6);
    }

    /* ============ utils ============ */
    function _resetInitializerImplementation(address implementation) internal {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        // Set the storage slot to uninitialized
        vm.store(address(implementation), INITIALIZABLE_STORAGE, 0);
    }
}
