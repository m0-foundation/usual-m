// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../../../lib/forge-std/src/Test.sol";
import { Pausable } from "../../../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

import { MockWrappedM, MockRegistryAccess } from "../../utils/Mocks.sol";

import {
    DEFAULT_ADMIN_ROLE,
    USUAL_M_UNWRAP,
    USUAL_M_PAUSE,
    USUAL_M_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_M_MINTCAP_ALLOCATOR
} from "../../../src/usual/constants.sol";
import { UsualM } from "../../../src/usual/UsualM.sol";

import { IUsualM } from "../../../src/usual/interfaces/IUsualM.sol";

contract UsualMUnitTests is Test {
    address internal _treasury = makeAddr("treasury");

    address internal _admin = makeAddr("admin");
    address internal _pauser = makeAddr("pauser");
    address internal _unpauser = makeAddr("unpauser");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _david = makeAddr("david");

    address internal _other = makeAddr("other");

    address internal _blacklister = makeAddr("blacklister");

    address internal _mintCapAllocator = makeAddr("mintCapAllocator");

    address[] internal _accounts = [_alice, _bob, _charlie, _david];

    MockWrappedM internal _wrappedM;
    MockRegistryAccess internal _registryAccess;

    UsualM internal _usualM;

    event MintCapSet(uint256 newMintCap);

    function setUp() external {
        _wrappedM = new MockWrappedM();
        _registryAccess = new MockRegistryAccess();

        // Set default admin role.
        _registryAccess.grantRole(DEFAULT_ADMIN_ROLE, _admin);

        _usualM = new UsualM();
        _resetInitializerImplementation(address(_usualM));
        _usualM.initialize(address(_wrappedM), address(_registryAccess));

        // Set pauser/unpauser role.
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_PAUSE, _pauser);
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_UNPAUSE, _unpauser);

        // Grant BLACKLIST_ROLE to the blacklister instead of admin
        vm.prank(_admin);
        _registryAccess.grantRole(BLACKLIST_ROLE, _blacklister);

        // Fund accounts with WrappedM tokens and allow them to unwrap.
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _wrappedM.setBalanceOf(_accounts[i], 10e6);

            vm.prank(_admin);
            _registryAccess.grantRole(USUAL_M_UNWRAP, _accounts[i]);
        }

        // Add mint cap allocator role to a separate address
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_MINTCAP_ALLOCATOR, _mintCapAllocator);

        // Set an initial mint cap
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(10_000e6);
    }

    /* ============ initialization ============ */
    function test_init() external view {
        assertEq(_usualM.wrappedM(), address(_wrappedM));
        assertEq(_usualM.registryAccess(), address(_registryAccess));
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
    }

    /* ============ wrap ============ */
    function test_wrap_wholeBalance() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        assertEq(_wrappedM.balanceOf(_alice), 0);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 10e6);

        assertEq(_usualM.balanceOf(_alice), 10e6);
    }

    function test_wrap() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 5e6);

        assertEq(_wrappedM.balanceOf(_alice), 5e6);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 5e6);

        assertEq(_usualM.balanceOf(_alice), 5e6);
    }

    function test_wrapWithPermit() external {
        vm.prank(_bob);
        _usualM.wrapWithPermit(_alice, 5e6, 0, 0, bytes32(0), bytes32(0));

        assertEq(_wrappedM.balanceOf(_alice), 10e6);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 5e6);
        assertEq(_usualM.balanceOf(_alice), 5e6);

        assertEq(_usualM.balanceOf(_bob), 0);
    }

    function test_wrapWithPermit_invalidAmount() external {
        vm.expectRevert(IUsualM.InvalidAmount.selector);

        vm.prank(_bob);
        _usualM.wrapWithPermit(_alice, 0, 0, 0, bytes32(0), bytes32(0));
    }

    function test_wrap_exceedsMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(5e6);

        vm.expectRevert(IUsualM.MintCapExceeded.selector);

        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);
    }

    function test_wrap_upToMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(15e6);

        // First wrap should succeed
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        // Second wrap should succeed (within cap)
        vm.prank(_bob);
        _usualM.wrap(_bob, 5e6);

        // Third wrap should fail (exceeds cap)
        vm.expectRevert(IUsualM.MintCapExceeded.selector);

        vm.prank(_charlie);
        _usualM.wrap(_charlie, 1e6);
    }

    function test_wrap_invalidAmount() external {
        vm.expectRevert(IUsualM.InvalidAmount.selector);

        vm.prank(_alice);
        _usualM.wrap(_alice, 0);
    }

    function testFuzz_wrap_withMintCap(uint256 mintCap, uint256 wrapAmount) external {
        mintCap = bound(mintCap, 1e6, 1e9);
        wrapAmount = bound(wrapAmount, 1, mintCap);

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(mintCap);

        _wrappedM.setBalanceOf(_alice, wrapAmount);

        // Wrap tokens up to the mint cap
        vm.prank(_alice);
        _usualM.wrap(_alice, wrapAmount);

        // Check that the total supply does not exceed the mint cap
        assertLe(_usualM.totalSupply(), mintCap);

        // Check that the wrapped amount is correct
        assertEq(_usualM.balanceOf(_alice), wrapAmount);
    }

    /* ============ unwrap ============ */
    function test_unwrap() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_alice);
        _usualM.unwrap(_alice, 5e6);

        assertEq(_wrappedM.balanceOf(_alice), 5e6);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 5e6);

        assertEq(_usualM.balanceOf(_alice), 5e6);
    }

    function test_unwrap_wholeBalance() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        assertEq(_wrappedM.balanceOf(_alice), 0);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 10e6);
        assertEq(_usualM.balanceOf(_alice), 10e6);

        vm.prank(_alice);
        _usualM.unwrap(_alice, 10e6);

        assertEq(_wrappedM.balanceOf(_alice), 10e6);
        assertEq(_wrappedM.balanceOf(address(_usualM)), 0);

        assertEq(_usualM.balanceOf(_alice), 0);
    }

    function test_unwarp_notAllowed() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.unwrap(_other, 5e6);
    }

    function test_unwrap_invalidAmount() external {
        vm.expectRevert(IUsualM.InvalidAmount.selector);

        vm.prank(_alice);
        _usualM.unwrap(_alice, 0);
    }

    /* ============ pause ============ */
    function test_pause_wrap() external {
        vm.prank(_pauser);
        _usualM.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);
    }

    function test_pause_transfer() external {
        vm.prank(_pauser);
        _usualM.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _usualM.transfer(_bob, 5e6);
    }

    function test_pause_unwrap() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_pauser);
        _usualM.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _usualM.unwrap(_bob, 10e6);
    }

    function test_pause_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.pause();
    }

    function test_unpause_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.unpause();
    }

    /* ============ blacklist ============ */
    function test_blacklisted_wrap() external {
        assertEq(_usualM.isBlacklisted(_alice), false);

        vm.prank(_blacklister);
        _usualM.blacklist(_alice);

        assertEq(_usualM.isBlacklisted(_alice), true);

        vm.expectRevert(IUsualM.Blacklisted.selector);

        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);
    }

    function test_blacklisted_unwrap() external {
        assertEq(_usualM.isBlacklisted(_alice), false);

        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_blacklister);
        _usualM.blacklist(_alice);

        assertEq(_usualM.isBlacklisted(_alice), true);

        vm.expectRevert(IUsualM.Blacklisted.selector);

        vm.prank(_alice);
        _usualM.unwrap(_alice, 10e6);
    }

    function test_blacklisted_transfer_sender() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_blacklister);
        _usualM.blacklist(_alice);

        vm.expectRevert(IUsualM.Blacklisted.selector);

        vm.prank(_alice);
        _usualM.transfer(_bob, 10e6);
    }

    function test_blacklisted_transfer_receiver() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_blacklister);
        _usualM.blacklist(_bob);

        vm.expectRevert(IUsualM.Blacklisted.selector);

        vm.prank(_alice);
        _usualM.transfer(_bob, 10e6);
    }

    function test_blacklist_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.blacklist(_alice);
    }

    function test_unBlacklist_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.unBlacklist(_alice);
    }

    function test_blacklist_unBlacklist() external {
        vm.prank(_blacklister);
        _usualM.blacklist(_alice);

        assertEq(_usualM.isBlacklisted(_alice), true);

        vm.expectRevert(IUsualM.Blacklisted.selector);

        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.prank(_blacklister);
        _usualM.unBlacklist(_alice);

        vm.prank(_alice);
        uint256 res = _usualM.wrap(_alice, 10e6);
        assertEq(res, 10e6);

        assertEq(_usualM.isBlacklisted(_alice), false);
    }

    function test_blacklist_zeroAddress() external {
        vm.expectRevert(IUsualM.ZeroAddress.selector);

        vm.prank(_blacklister);
        _usualM.blacklist(address(0));
    }

    function test_unBlacklist_zeroAddress() external {
        vm.expectRevert(IUsualM.ZeroAddress.selector);

        vm.prank(_blacklister);
        _usualM.unBlacklist(address(0));
    }

    function test_blacklist_sameValue() external {
        vm.prank(_blacklister);
        _usualM.blacklist(_alice);

        vm.expectRevert(IUsualM.SameValue.selector);

        vm.prank(_blacklister);
        _usualM.blacklist(_alice);
    }

    function test_unBlacklist_sameValue() external {
        vm.expectRevert(IUsualM.SameValue.selector);

        vm.prank(_blacklister);
        _usualM.unBlacklist(_alice);
    }

    /* ============ mint cap ============ */
    function test_setMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);

        assertEq(_usualM.mintCap(), 100e6);
    }

    function test_setMintCap_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);

        vm.prank(_other);
        _usualM.setMintCap(100e6);
    }

    function test_setMintCap_sameValue() external {
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);

        vm.expectRevert(IUsualM.SameValue.selector);

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);
    }

    function test_setMintCap_uint96() external {
        vm.expectRevert(IUsualM.InvalidUInt96.selector);

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(2 ** 96);
    }

    function test_setMintCap_emitsEvent() external {
        vm.expectEmit(false, false, false, true);
        emit MintCapSet(100e6);

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);
    }

    /* ============ wrappable amount ============ */
    function test_getWrappableAmount() external {
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);

        // Initially, wrappable amount should be the full mint cap
        assertEq(_usualM.getWrappableAmount(100e6), 100e6);

        // Wrap some tokens
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        // Check wrappable amount with amount exceeding difference between mint cap and total supply
        assertEq(_usualM.getWrappableAmount(100e6), 90e6);

        // Check wrappable amount with amount less than difference between mint cap and total supply
        assertEq(_usualM.getWrappableAmount(20e6), 20e6);
    }

    /* ============ utils ============ */
    function _resetInitializerImplementation(address implementation) internal {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        // Set the storage slot to uninitialized
        vm.store(address(implementation), INITIALIZABLE_STORAGE, 0);
    }
}
