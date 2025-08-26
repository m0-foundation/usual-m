// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IERC20 } from "../../../lib/forge-std/src/interfaces/IERC20.sol";

import { Pausable } from "../../../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

import { Upgrades } from "../../../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "../../../lib/openzeppelin-foundry-upgrades/src/Options.sol";

import { ISwapFacilityLike } from "../../../src/usual/interfaces/ISwapFacilityLike.sol";

import { MockMToken, MockRegistryAccess, MockSwapFacility, MockWrappedM } from "../../utils/Mocks.sol";

import {
    DEFAULT_ADMIN_ROLE,
    USUAL_M_UNWRAP,
    USUAL_M_PAUSE,
    USUAL_M_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_M_MINTCAP_ALLOCATOR,
    USUAL_M_YIELD_RECIPIENT_SETTER
} from "../../../src/usual/constants.sol";

import { UsualM } from "../../../src/usual/UsualM.sol";
import { UsualMV2 } from "../../../src/usual/UsualMV2.sol";

import { IUsualMV2 } from "../../../src/usual/interfaces/IUsualMV2.sol";

contract UsualMV2UnitTests is Test {
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
    address internal _disableEarning = makeAddr("disableEarning");
    address internal _yieldRecipientSetter = makeAddr("yieldRecipientSetter");
    address internal _yieldRecipient = makeAddr("yieldRecipient");

    address[] internal _accounts = [_alice, _bob, _charlie, _david];

    MockWrappedM internal _wrappedM;
    MockMToken internal _mToken;
    MockRegistryAccess internal _registryAccess;
    MockSwapFacility internal _swapFacility;

    UsualM internal _usualM;
    UsualMV2 internal _usualMV2;

    event MintCapSet(uint256 newMintCap);

    function setUp() external {
        _wrappedM = new MockWrappedM();
        _mToken = new MockMToken();
        _registryAccess = new MockRegistryAccess();
        _swapFacility = new MockSwapFacility(address(_mToken));

        // Set default admin role.
        _registryAccess.grantRole(DEFAULT_ADMIN_ROLE, _admin);

        address usualM_ = Upgrades.deployTransparentProxy(
            "UsualM.sol:UsualM",
            _admin,
            abi.encodeWithSelector(UsualM.initialize.selector, address(_wrappedM), address(_registryAccess))
        );

        _wrappedM.setClaimRecipient(usualM_, _yieldRecipient);

        Options memory opts;
        opts.unsafeAllow = "missing-initializer";

        Upgrades.upgradeProxy(
            usualM_,
            "UsualMV2.sol:UsualMV2",
            abi.encodeCall(UsualMV2.initializeV2, (address(_mToken), address(_swapFacility), _yieldRecipient)),
            opts,
            _admin
        );

        _usualMV2 = UsualMV2(usualM_);

        // Set pauser/unpauser role.
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_PAUSE, _pauser);

        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_UNPAUSE, _unpauser);

        // Grant BLACKLIST_ROLE to the blacklister instead of admin
        vm.prank(_admin);
        _registryAccess.grantRole(BLACKLIST_ROLE, _blacklister);

        // Fund accounts with M tokens and allow them to unwrap.
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _mToken.setBalanceOf(_accounts[i], 10e6);

            vm.prank(_admin);
            _registryAccess.grantRole(USUAL_M_UNWRAP, _accounts[i]);
        }

        // Add mint cap allocator role to a separate address
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_MINTCAP_ALLOCATOR, _mintCapAllocator);

        // Set an initial mint cap
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(10_000e6);

        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_YIELD_RECIPIENT_SETTER, _yieldRecipientSetter);
    }

    /* ============ initialization ============ */
    function test_init() external view {
        assertEq(_usualMV2.name(), "UsualM");
        assertEq(_usualMV2.symbol(), "USUALM");
        assertEq(_usualMV2.decimals(), 6);
        assertEq(_usualMV2.registryAccess(), address(_registryAccess));
        assertEq(_usualMV2.mToken(), address(_mToken));
        assertEq(_usualMV2.swapFacility(), address(_swapFacility));
        assertEq(_usualMV2.yieldRecipient(), _yieldRecipient);
    }

    /* ============ claimYield ============ */
    function test_claimYield_noYield() external {
        vm.prank(_alice);
        assertEq(_usualMV2.claimYield(), 0);
    }

    function test_claimYield() external {
        _mToken.setBalanceOf(_alice, 1_000);

        _wrap(_alice, _alice, 1_000);

        _mToken.setBalanceOf(address(_usualMV2), _usualMV2.totalSupply() + 500);

        assertEq(_usualMV2.yield(), 500);

        vm.expectEmit();
        emit IUsualMV2.YieldClaimed(500);

        _usualMV2.claimYield();

        assertEq(_usualMV2.yield(), 0);

        assertEq(_mToken.balanceOf(address(_usualMV2)), _usualMV2.totalSupply());
        assertEq(_mToken.balanceOf(address(_usualMV2)), 1_500);

        assertEq(_mToken.balanceOf(_yieldRecipient), 0);
        assertEq(_usualMV2.balanceOf(_yieldRecipient), 500);
    }

    /* ============ wrap ============ */
    function test_wrap_wholeBalance() external {
        _wrap(_alice, _alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_usualMV2)), 10e6);

        assertEq(_usualMV2.balanceOf(_alice), 10e6);
    }

    function test_wrap() external {
        _wrap(_alice, _alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(address(_usualMV2)), 5e6);

        assertEq(_usualMV2.balanceOf(_alice), 5e6);
    }

    function test_wrap_exceedsMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(5e6);

        vm.prank(_alice);
        IERC20(address(_mToken)).approve(address(_swapFacility), 10e6);

        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(_alice)
        );

        vm.expectRevert(IUsualMV2.MintCapExceeded.selector);

        vm.prank(_alice);
        _swapFacility.swapInM(address(_usualMV2), 10e6, _alice);
    }

    function test_wrap_upToMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(15e6);

        // First wrap should succeed
        _wrap(_alice, _alice, 10e6);

        // Second wrap should succeed (within cap)
        _wrap(_bob, _bob, 5e6);

        vm.prank(_charlie);
        _usualMV2.approve(address(_swapFacility), 1e6);

        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(_charlie)
        );

        // Third wrap should fail (exceeds cap)
        vm.expectRevert(IUsualMV2.MintCapExceeded.selector);

        vm.prank(_charlie);
        _swapFacility.swapInM(address(_usualMV2), 1e6, _charlie);
    }

    function test_wrap_invalidAmount() external {
        vm.expectRevert(IUsualMV2.InvalidAmount.selector);

        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(_alice)
        );

        vm.prank(_alice);
        _swapFacility.swapInM(address(_usualMV2), 0, _alice);
    }

    function testFuzz_wrap_withMintCap(uint256 mintCap, uint256 wrapAmount) external {
        mintCap = bound(mintCap, 1e6, 1e9);
        wrapAmount = bound(wrapAmount, 1, mintCap);

        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(mintCap);

        _mToken.setBalanceOf(_alice, wrapAmount);

        // Wrap tokens up to the mint cap
        _wrap(_alice, _alice, wrapAmount);

        // Check that the total supply does not exceed the mint cap
        assertLe(_usualMV2.totalSupply(), mintCap);

        // Check that the wrapped amount is correct
        assertEq(_usualMV2.balanceOf(_alice), wrapAmount);
    }

    /* ============ unwrap ============ */
    function test_unwrap() external {
        _wrap(_alice, _alice, 10e6);
        _unwrap(_alice, _alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(address(_usualMV2)), 5e6);

        assertEq(_usualMV2.balanceOf(_alice), 5e6);
    }

    function test_unwrap_wholeBalance() external {
        _wrap(_alice, _alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_usualMV2)), 10e6);
        assertEq(_usualMV2.balanceOf(_alice), 10e6);

        _unwrap(_alice, _alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(address(_usualMV2)), 0);

        assertEq(_usualMV2.balanceOf(_alice), 0);
    }

    function test_unwrap_notAllowed() external {
        _mToken.setBalanceOf(_other, 5e6);
        _wrap(_other, _other, 5e6);

        vm.prank(_other);
        _usualMV2.approve(address(_swapFacility), 5e6);

        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(_other)
        );

        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _swapFacility.swapOutM(address(_usualMV2), 5e6, _alice);
    }

    function test_unwrap_invalidAmount() external {
        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(_alice)
        );

        vm.expectRevert(IUsualMV2.InvalidAmount.selector);

        vm.prank(_alice);
        _swapFacility.swapOutM(address(_usualMV2), 0, _alice);
    }

    /* ============ pause ============ */
    function test_pause_wrap() external {
        vm.prank(_pauser);
        _usualMV2.pause();

        vm.prank(_alice);
        _usualMV2.approve(address(_swapFacility), 10e6);

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _swapFacility.swapInM(address(_usualMV2), 10e6, _alice);
    }

    function test_pause_transfer() external {
        vm.prank(_pauser);
        _usualMV2.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _usualMV2.transfer(_bob, 5e6);
    }

    function test_pause_unwrap() external {
        _wrap(_alice, _alice, 10e6);

        vm.prank(_pauser);
        _usualMV2.pause();

        vm.prank(_alice);
        _usualMV2.approve(address(_swapFacility), 10e6);

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(_alice);
        _swapFacility.swapOutM(address(_usualMV2), 10e6, _alice);
    }

    function test_pause_unauthorized() external {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _usualMV2.pause();
    }

    function test_unpause_unauthorized() external {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _usualMV2.unpause();
    }

    /* ============ blacklist ============ */
    function test_blacklisted_wrap() external {
        assertEq(_usualMV2.isBlacklisted(_alice), false);

        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);

        assertEq(_usualMV2.isBlacklisted(_alice), true);

        vm.prank(_alice);
        IERC20(address(_mToken)).approve(address(_swapFacility), 10e6);

        vm.expectRevert(IUsualMV2.Blacklisted.selector);

        vm.prank(_alice);
        _swapFacility.swapInM(address(_usualMV2), 10e6, _alice);
    }

    function test_blacklisted_unwrap() external {
        assertEq(_usualMV2.isBlacklisted(_alice), false);

        _wrap(_alice, _alice, 10e6);

        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);

        assertEq(_usualMV2.isBlacklisted(_alice), true);

        vm.prank(_alice);
        _usualMV2.approve(address(_swapFacility), 10e6);

        vm.expectRevert(IUsualMV2.Blacklisted.selector);

        vm.prank(_alice);
        _swapFacility.swapOutM(address(_usualMV2), 10e6, _alice);
    }

    function test_blacklisted_transfer_sender() external {
        _wrap(_alice, _alice, 10e6);

        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);

        vm.expectRevert(IUsualMV2.Blacklisted.selector);

        vm.prank(_alice);
        _usualMV2.transfer(_bob, 10e6);
    }

    function test_blacklisted_transfer_receiver() external {
        _wrap(_alice, _alice, 10e6);

        vm.prank(_blacklister);
        _usualMV2.blacklist(_bob);

        vm.expectRevert(IUsualMV2.Blacklisted.selector);

        vm.prank(_alice);
        _usualMV2.transfer(_bob, 10e6);
    }

    function test_blacklist_unauthorized() external {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _usualMV2.blacklist(_alice);
    }

    function test_unBlacklist_unauthorized() external {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _usualMV2.unBlacklist(_alice);
    }

    function test_blacklist_unBlacklist() external {
        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);

        assertEq(_usualMV2.isBlacklisted(_alice), true);

        vm.prank(_alice);
        IERC20(address(_mToken)).approve(address(_swapFacility), 10e6);

        vm.expectRevert(IUsualMV2.Blacklisted.selector);

        vm.prank(_alice);
        _swapFacility.swapInM(address(_usualMV2), 10e6, _alice);

        vm.prank(_blacklister);
        _usualMV2.unBlacklist(_alice);

        _wrap(_alice, _alice, 10e6);

        assertEq(_usualMV2.balanceOf(_alice), 10e6);
        assertEq(_usualMV2.isBlacklisted(_alice), false);
    }

    function test_blacklist_zeroAddress() external {
        vm.expectRevert(IUsualMV2.ZeroAddress.selector);

        vm.prank(_blacklister);
        _usualMV2.blacklist(address(0));
    }

    function test_unBlacklist_zeroAddress() external {
        vm.expectRevert(IUsualMV2.ZeroAddress.selector);

        vm.prank(_blacklister);
        _usualMV2.unBlacklist(address(0));
    }

    function test_blacklist_sameValue() external {
        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);

        vm.expectRevert(IUsualMV2.SameValue.selector);

        vm.prank(_blacklister);
        _usualMV2.blacklist(_alice);
    }

    function test_unBlacklist_sameValue() external {
        vm.expectRevert(IUsualMV2.SameValue.selector);

        vm.prank(_blacklister);
        _usualMV2.unBlacklist(_alice);
    }

    /* ============ mint cap ============ */
    function test_setMintCap() external {
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(100e6);

        assertEq(_usualMV2.mintCap(), 100e6);
    }

    function test_setMintCap_unauthorized() external {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_other);
        _usualMV2.setMintCap(100e6);
    }

    function test_setMintCap_sameValue() external {
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(100e6);

        vm.expectRevert(IUsualMV2.SameValue.selector);

        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(100e6);
    }

    function test_setMintCap_uint96() external {
        vm.expectRevert(IUsualMV2.InvalidUInt96.selector);

        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(2 ** 96);
    }

    function test_setMintCap_emitsEvent() external {
        vm.expectEmit(false, false, false, true);
        emit MintCapSet(100e6);

        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(100e6);
    }

    /* ============ setYieldRecipient ============ */
    function test_setYieldRecipient_onlyYieldRecipientSetter() public {
        vm.expectRevert(IUsualMV2.NotAuthorized.selector);

        vm.prank(_alice);
        _usualMV2.setYieldRecipient(_alice);
    }

    function test_setYieldRecipient_zeroYieldRecipient() public {
        vm.expectRevert(IUsualMV2.ZeroYieldRecipient.selector);

        vm.prank(_yieldRecipientSetter);
        _usualMV2.setYieldRecipient(address(0));
    }

    function test_setYieldRecipient_noUpdate() public {
        assertEq(_usualMV2.yieldRecipient(), _yieldRecipient);

        vm.prank(_yieldRecipientSetter);
        _usualMV2.setYieldRecipient(_yieldRecipient);

        assertEq(_usualMV2.yieldRecipient(), _yieldRecipient);
    }

    function test_setYieldRecipient() public {
        assertEq(_usualMV2.yieldRecipient(), _yieldRecipient);

        vm.expectEmit();
        emit IUsualMV2.YieldRecipientSet(_alice);

        vm.prank(_yieldRecipientSetter);
        _usualMV2.setYieldRecipient(_alice);

        assertEq(_usualMV2.yieldRecipient(), _alice);
    }

    /* ============ disableEarning ============ */
    function test_disableEarning_earningIsDisabled() external {
        _usualMV2.disableEarning();

        vm.expectRevert(IUsualMV2.EarningIsDisabled.selector);
        _usualMV2.disableEarning();
    }

    function test_disableEarning() external {
        assertTrue(_usualMV2.isEarningEnabled());

        _usualMV2.disableEarning();
        assertFalse(_usualMV2.isEarningEnabled());
    }

    /* ============ yield ============ */
    function test_yield() external {
        _mToken.setBalanceOf(_alice, 1_000);
        _mToken.setBalanceOf(_bob, 1_000);

        _wrap(_alice, _alice, 1_000);
        _wrap(_bob, _bob, 1_000);

        assertEq(_usualMV2.yield(), 0);

        _mToken.setBalanceOf(address(_usualMV2), _usualMV2.totalSupply() + 500);

        assertEq(_usualMV2.yield(), 500);
    }

    /* ============ wrappable amount ============ */
    function test_getWrappableAmount() external {
        vm.prank(_mintCapAllocator);
        _usualMV2.setMintCap(100e6);

        // Initially, wrappable amount should be the full mint cap
        assertEq(_usualMV2.getWrappableAmount(100e6), 100e6);

        // Wrap some tokens
        _wrap(_alice, _alice, 10e6);

        // Check wrappable amount with amount exceeding difference between mint cap and total supply
        assertEq(_usualMV2.getWrappableAmount(100e6), 90e6);

        // Check wrappable amount with amount less than difference between mint cap and total supply
        assertEq(_usualMV2.getWrappableAmount(20e6), 20e6);
    }

    function _wrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        IERC20(address(_mToken)).approve(address(_swapFacility), amount_);

        vm.prank(account_);
        _swapFacility.swapInM(address(_usualMV2), amount_, recipient_);
    }

    function _unwrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _usualMV2.approve(address(_swapFacility), amount_);

        vm.mockCall(
            address(_swapFacility),
            abi.encodeWithSelector(ISwapFacilityLike.msgSender.selector),
            abi.encode(account_)
        );

        vm.prank(account_);
        _swapFacility.swapOutM(address(_usualMV2), amount_, recipient_);
    }
}
