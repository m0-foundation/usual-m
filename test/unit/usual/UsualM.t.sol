// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { Pausable } from "../../../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";

import { MockMToken, MockRegistryAccess } from "../../utils/Mocks.sol";

import {
    DEFAULT_ADMIN_ROLE,
    USUAL_M_UNWRAP,
    USUAL_M_PAUSE,
    USUAL_M_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_M_MINTCAP_ALLOCATOR,
    M_ENABLE_EARNING,
    M_DISABLE_EARNING,
    M_CLAIM_EXCESS
} from "../../../src/usual/constants.sol";
import { UsualM } from "../../../src/usual/UsualM.sol";

import { IUsualM } from "../../../src/usual/interfaces/IUsualM.sol";
import { IMTokenLike } from "../../../src/usual/interfaces/IMTokenLike.sol";

contract UsualMUnitTests is Test {
    uint56 internal constant EXP_SCALED_ONE = 1e12;

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

    address internal _mEarningEnabler = makeAddr("mEarningEnabler");
    address internal _mEarningDisabler = makeAddr("mEarningDisabler");
    address internal _mExcessClaimer = makeAddr("mClaimer");

    address[] internal _accounts = [_alice, _bob, _charlie, _david];

    MockMToken internal _mToken;
    MockRegistryAccess internal _registryAccess;

    UsualM internal _usualM;

    function setUp() external {
        _mToken = new MockMToken();
        _registryAccess = new MockRegistryAccess();

        // Set initial index
        _mToken.setCurrentIndex(EXP_SCALED_ONE);

        // Set default admin role.
        _registryAccess.grantRole(DEFAULT_ADMIN_ROLE, _admin);

        _usualM = new UsualM();
        _resetInitializerImplementation(address(_usualM));
        _usualM.initialize(address(_mToken), address(_registryAccess));

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
            address account_ = _accounts[i];

            _mToken.setBalanceOf(account_, 10e6);
            _mToken.setIsEarning(account_, false);

            vm.prank(_admin);
            _registryAccess.grantRole(USUAL_M_UNWRAP, account_);
        }

        // Grant M_ENABLE_EARNING and M_DISABLE_EARNING roles
        vm.prank(_admin);
        _registryAccess.grantRole(M_ENABLE_EARNING, _mEarningEnabler);

        vm.prank(_admin);
        _registryAccess.grantRole(M_DISABLE_EARNING, _mEarningDisabler);

        // Grant M_CLAIM_EXCESS role
        vm.prank(_admin);
        _registryAccess.grantRole(M_CLAIM_EXCESS, _mExcessClaimer);

        // Add mint cap allocator role to a separate address
        vm.prank(_admin);
        _registryAccess.grantRole(USUAL_M_MINTCAP_ALLOCATOR, _mintCapAllocator);

        // Set an initial mint cap
        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(10_000e6);
    }

    /* ============ initialization ============ */
    function test_init() external view {
        assertEq(_usualM.mToken(), address(_mToken));
        assertEq(_usualM.registryAccess(), address(_registryAccess));
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
    }

    /* ============ wrap ============ */
    function test_wrap_wholeBalance() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_usualM)), 10e6);

        assertEq(_usualM.balanceOf(_alice), 10e6);
    }

    function test_wrap() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(address(_usualM)), 5e6);

        assertEq(_usualM.balanceOf(_alice), 5e6);
    }

    function test_wrapWithPermit() external {
        vm.prank(_bob);
        _usualM.wrapWithPermit(_alice, 5e6, 0, 0, bytes32(0), bytes32(0));

        assertEq(_mToken.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(address(_usualM)), 5e6);
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

        _mToken.setBalanceOf(_alice, wrapAmount);

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

        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.isEarning.selector, _alice),
            abi.encode(false)
        );

        vm.prank(_alice);
        _usualM.unwrap(_alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(address(_usualM)), 5e6);

        assertEq(_usualM.balanceOf(_alice), 5e6);
    }

    function test_unwrap_usualMNotEarning() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        vm.mockCall(address(_mToken), abi.encodeWithSelector(IMTokenLike.isEarning.selector, _alice), abi.encode(true));
        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.isEarning.selector, address(_usualM)),
            abi.encode(false)
        );

        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.principalBalanceOf.selector, _alice),
            abi.encode(0)
        );

        vm.prank(_alice);
        _usualM.unwrap(_alice, 5e6);

        assertEq(_mToken.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(address(_usualM)), 5e6);

        assertEq(_usualM.balanceOf(_alice), 5e6);
    }

    function test_unwrap_wholeBalance() external {
        vm.prank(_alice);
        _usualM.wrap(_alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_usualM)), 10e6);
        assertEq(_usualM.balanceOf(_alice), 10e6);

        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.isEarning.selector, _alice),
            abi.encode(false)
        );

        vm.prank(_alice);
        _usualM.unwrap(_alice, 10e6);

        assertEq(_mToken.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(address(_usualM)), 0);

        assertEq(_usualM.balanceOf(_alice), 0);
    }

    function test_unwrap_notAllowed() external {
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
        emit IUsualM.MintCapSet(100e6);

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(100e6);
    }

    /* ============ startEarningM ============ */
    function test_startEarningM() external {
        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.startEarning, ()));

        vm.expectEmit();
        emit IUsualM.StartedEarningM();

        vm.prank(_mEarningEnabler);
        _usualM.startEarningM();
    }

    function test_startEarningM_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);
        _usualM.startEarningM();
    }

    /* ============ stopEarningM ============ */
    function test_stopEarningM() external {
        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.stopEarning, ()));

        vm.expectEmit();
        emit IUsualM.StoppedEarningM();

        vm.prank(_mEarningDisabler);
        _usualM.stopEarningM();
    }

    function test_stopEarningM_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);
        _usualM.stopEarningM();
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

    /* ============ excess ============ */
    function test_excessM() external {
        uint256 amount_ = 100e6;
        uint240 yield_ = 10e6;

        // Fund alice account with 100 M tokens
        _mToken.setBalanceOf(_alice, amount_);

        // Wrap some tokens
        vm.prank(_alice);
        _usualM.wrap(_alice, amount_);

        // Simulate yield accumulation
        _mToken.setBalanceOf(address(_usualM), amount_ + yield_);
        _mToken.setIsEarning(address(_usualM), true);

        // Check excess
        assertEq(uint240(int240(_usualM.excessM())), yield_);
    }

    function test_excessM_noYield() external {
        uint256 amount_ = 100e6;

        _mToken.setBalanceOf(_alice, amount_);

        // Wrap some tokens
        vm.prank(_alice);
        _usualM.wrap(_alice, amount_);

        // No yield has accumulated yet
        _mToken.setBalanceOf(address(_usualM), amount_);

        // Check excess
        assertEq(_usualM.excessM(), 0);
    }

    function testFuzz_excessM(uint128 currentMIndex_, uint256 wrapAmount_) external {
        _mToken.setCurrentIndex(EXP_SCALED_ONE);

        uint256 maxAmount_ = type(uint96).max;

        vm.prank(_mintCapAllocator);
        _usualM.setMintCap(maxAmount_);

        wrapAmount_ = bound(wrapAmount_, 0, maxAmount_);
        if (wrapAmount_ == 0) return;

        _mToken.setBalanceOf(_alice, wrapAmount_);

        vm.prank(_alice);
        wrapAmount_ = _usualM.wrap(_alice, wrapAmount_);

        _mToken.setIsEarning(address(_usualM), true);

        uint256 mTokenBalanceBefore_ = _mToken.balanceOf(address(_usualM));
        uint112 mTokenPrincipalBalance_ = IndexingMath.getPrincipalAmountRoundedUp(
            uint240(mTokenBalanceBefore_),
            EXP_SCALED_ONE
        );

        // Simulate yield accumulation
        currentMIndex_ = uint128(bound(currentMIndex_, EXP_SCALED_ONE, 10 * EXP_SCALED_ONE));
        _mToken.setCurrentIndex(currentMIndex_);

        _mToken.setBalanceOf(
            address(_usualM),
            IndexingMath.getPresentAmountRoundedDown(mTokenPrincipalBalance_, currentMIndex_)
        );

        uint240 yield_ = uint240(_mToken.balanceOf(address(_usualM)) - mTokenBalanceBefore_);

        assertEq(_usualM.excessM(), int248(uint248(yield_)));
    }

    /* ============ claimExcessM ============ */
    function test_claimExcessM() external {
        uint256 amount_ = 100e6;
        uint240 yield_ = 10e6;

        // Fund alice account with 100 M tokens
        _mToken.setBalanceOf(_alice, amount_);

        // Wrap some tokens
        vm.prank(_alice);
        _usualM.wrap(_alice, amount_);

        // Simulate yield accumulation
        _mToken.setBalanceOf(address(_usualM), amount_ + yield_);

        assertEq(_mToken.balanceOf(_treasury), 0);

        vm.prank(_mExcessClaimer);

        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.principalBalanceOf.selector, address(_usualM)),
            abi.encode(IndexingMath.getPrincipalAmountRoundedUp(uint240(amount_ + yield_), EXP_SCALED_ONE))
        );

        vm.mockCall(
            address(_mToken),
            abi.encodeWithSelector(IMTokenLike.isEarning.selector, address(_usualM)),
            abi.encode(true)
        );

        vm.expectEmit();
        emit IUsualM.ClaimedExcessM(_treasury, yield_);

        assertEq(_usualM.claimExcessM(_treasury), yield_);
        assertEq(_mToken.balanceOf(_treasury), yield_);
    }

    function test_claimExcessM_unauthorized() external {
        vm.expectRevert(IUsualM.NotAuthorized.selector);
        _usualM.claimExcessM(_treasury);
    }

    function test_claimExcessM_noYield() external {
        vm.expectRevert(IUsualM.NoExcessM.selector);
        vm.prank(_mExcessClaimer);

        assertEq(_usualM.claimExcessM(_treasury), 0);
        assertEq(_mToken.balanceOf(_treasury), 0);
    }

    /* ============ utils ============ */

    function _resetInitializerImplementation(address implementation) internal {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        // Set the storage slot to uninitialized
        vm.store(address(implementation), INITIALIZABLE_STORAGE, 0);
    }
}
