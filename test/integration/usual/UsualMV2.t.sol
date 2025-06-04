// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;
import { console } from "../../../lib/forge-std/src/console.sol";
import { Test } from "../../../lib/forge-std/src/Test.sol";
import { Vm } from "../../../lib/forge-std/src/Vm.sol";
import { Upgrades } from "../../../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "../../../lib/openzeppelin-foundry-upgrades/src/Options.sol";

import { ProxyAdmin } from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC1967Utils } from "../../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import { UsualM } from "../../../src/usual/UsualM.sol";
import { UsualMV2 } from "../../../src/usual/UsualMV2.sol";

import { IMTokenLike } from "../../../src/usual/interfaces/IMTokenLike.sol";
import { IWrappedMLike } from "../../../src/usual/interfaces/IWrappedMLike.sol";
import { IUsualM } from "../../../src/usual/interfaces/IUsualM.sol";
import { IUsualMV2 } from "../../../src/usual/interfaces/IUsualMV2.sol";
import { IRegistryAccess } from "../../../src/usual/interfaces/IRegistryAccess.sol";
import { UpgradeUsualMBase } from "../../../script/upgrade/UpgradeUsualMBase.sol";

import { USUAL_M_MINTCAP_ALLOCATOR, USUAL_M_UNWRAP } from "../../../src/usual/constants.sol";

import { IERC20Like } from "../../utils/IERC20Like.sol";

import { TestBase } from "./TestBase.sol";

contract UsualMV2IntegrationTests is Test, UpgradeUsualMBase {
    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    address internal constant _USUAL_ADMIN = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7; // Usual default admin
    address internal constant _USUAL_REGISTRY_ACCESS = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56;
    address internal constant _USUAL_TREASURY = 0xdd82875f0840AAD58a455A70B88eEd9F59ceC7c7;
    address internal constant _WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    IMTokenLike internal constant _mToken = IMTokenLike(_M_TOKEN);
    IWrappedMLike internal constant _wrappedM = IWrappedMLike(_WRAPPED_M_TOKEN);

    // Large MToken holder on Ethereum Mainnet
    address internal constant _mTokenSource = 0x3f0376da3Ae4313E7a5F1dA184BAFC716252d759;

    // address internal _admin;
    address internal _treasury = makeAddr("treasury");

    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");

    address internal _earner = makeAddr("earner");
    address internal _nonEarner = makeAddr("nonEarner");

    address internal _alice;
    uint256 internal _aliceKey;

    address[] internal _accounts;

    IUsualMV2 internal _usualM;

    uint256 internal _wrappedMTokenBalanceBeforeUpgrade;

    uint256 public mainnetFork;

    function setUp() external {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"), 22_625_475);

        _wrappedMTokenBalanceBeforeUpgrade = _wrappedM.balanceOf(_USUAL_M_PROXY);

        (_alice, _aliceKey) = makeAddrAndKey("alice");
        _accounts = [_alice, _bob, _carol, _earner, _nonEarner];

        _fundAccounts();
        _grantRoles();

        _usualM = IUsualMV2(_USUAL_M_PROXY);

        // Check balances before unwrapping
        assertEq(_mToken.balanceOf(_USUAL_M_PROXY), 0);
        assertEq(_wrappedM.balanceOf(_USUAL_M_PROXY), _wrappedMTokenBalanceBeforeUpgrade);

        vm.startPrank(_USUAL_ADMIN);
        _upgradeUsualM();
        vm.stopPrank();
    }

    /* ============ constants ============ */

    function test_integration_constants() external {
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_usualM.registryAccess(), _USUAL_REGISTRY_ACCESS);
        assertEq(_usualM.mToken(), _M_TOKEN);
        assertEq(_usualM.yieldRecipient(), _USUAL_M_YIELD_RECIPIENT);
    }

    /* ============ yield ============ */

    function test_yieldAccumulationAndClaim() external {
        uint256 mTokenBalance = _mToken.balanceOf(_USUAL_M_PROXY);
        uint256 usualMTotalSupply = _usualM.totalSupply();
        uint256 amount = 10e6;

        _wrap(_alice, _alice, amount);

        // Check balances of UsualM and Alice after wrapping
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (amount - 1)); // M token rounds down for an earner
        assertEq(_usualM.totalSupply(), usualMTotalSupply += amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        uint256 yield = _usualM.yield();
        assertEq(yield, 666_301_404849);

        // Check balances before unwrapping Usual M
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(_USUAL_M_YIELD_RECIPIENT), 0);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (yield + 2)); // yield rounds down
        assertEq(_usualM.totalSupply(), usualMTotalSupply);

        // Unwrap UsualM
        _unwrap(_alice, _alice, amount);

        // Check balances after unwrapping
        assertEq(_usualM.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(_USUAL_M_YIELD_RECIPIENT), 0);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance -= amount);
        assertEq(_usualM.totalSupply(), usualMTotalSupply -= amount);

        _wrap(_bob, _bob, amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        yield = _usualM.yield();
        assertEq(yield, 1_339_323_220354);

        // Check balances before claiming M
        assertEq(_usualM.balanceOf(_bob), amount);
        assertEq(_mToken.balanceOf(_bob), 0);
        assertEq(_mToken.balanceOf(_USUAL_M_YIELD_RECIPIENT), 0);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (1_339_323_220354 - 666_301_404849 + amount));
        assertEq(_usualM.totalSupply(), usualMTotalSupply += amount);

        _usualM.claimYield();

        // Check balances after claiming  M
        assertEq(_usualM.balanceOf(_bob), amount);
        assertEq(_mToken.balanceOf(_bob), 0);
        assertEq(_usualM.balanceOf(_USUAL_M_YIELD_RECIPIENT), yield);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance);
        assertEq(_usualM.totalSupply(), usualMTotalSupply += yield);
        assertEq(_usualM.yield(), 0);
    }

    /* ============ wrap ============ */

    function test_wrap_fromEarnerToEarner() external {
        uint256 mTokenBalance = _mToken.balanceOf(_USUAL_M_PROXY);
        uint256 wrapAmount = 5e6;

        _wrap(_earner, _earner, wrapAmount);

        assertEq(_mToken.balanceOf(_earner), wrapAmount);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (wrapAmount - 1)); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_earner), wrapAmount);
    }

    function test_wrap_fromEarnerToNonEarner() external {
        uint256 mTokenBalance = _mToken.balanceOf(_USUAL_M_PROXY);
        uint256 wrapAmount = 5e6;

        _wrap(_earner, _nonEarner, wrapAmount);

        assertEq(_mToken.balanceOf(_earner), wrapAmount);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (wrapAmount - 1)); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_earner), 0);
        assertEq(_usualM.balanceOf(_nonEarner), wrapAmount);
    }

    function test_wrap_fromNonEarnerToNonEarner() external {
        uint256 mTokenBalance = _mToken.balanceOf(_USUAL_M_PROXY);
        uint256 wrapAmount = 5e6;

        _wrap(_nonEarner, _nonEarner, wrapAmount);

        assertEq(_mToken.balanceOf(_nonEarner), wrapAmount);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (wrapAmount - 1)); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), wrapAmount);
    }

    function test_wrap_fromNonEarnerToEarner() external {
        uint256 mTokenBalance = _mToken.balanceOf(_USUAL_M_PROXY);
        uint256 wrapAmount = 5e6;

        _wrap(_nonEarner, _earner, wrapAmount);

        assertEq(_mToken.balanceOf(_nonEarner), wrapAmount);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalance += (wrapAmount - 1)); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 0);
        assertEq(_usualM.balanceOf(_earner), wrapAmount);
    }

    function test_wrapWithPermits() external {
        assertEq(_mToken.balanceOf(_alice), 10e6);

        _wrapWithPermitVRS(_alice, _aliceKey, _alice, 5e6, 0, block.timestamp);

        assertEq(_usualM.balanceOf(_alice), 5e6);
        assertEq(_mToken.balanceOf(_alice), 5e6);

        _wrapWithPermitVRS(_alice, _aliceKey, _alice, 5e6, 1, block.timestamp);

        assertEq(_usualM.balanceOf(_alice), 10e6);
        assertEq(_mToken.balanceOf(_alice), 0);
    }

    function testFuzz_wrap(
        bool senderEarning_,
        bool recipientEarning_,
        uint256 wrapAmount_,
        uint128 currentMIndex_
    ) external {
        currentMIndex_ = uint128(bound(currentMIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        _mockCurrentMIndex(currentMIndex_);

        wrapAmount_ = bound(wrapAmount_, 0, _mToken.balanceOf(_mTokenSource));
        if (wrapAmount_ == 0) return;

        address sender_ = senderEarning_ ? _earner : _nonEarner;
        address recipient_ = recipientEarning_ ? _earner : _nonEarner;

        _giveMToken(sender_, wrapAmount_);

        uint256 senderMBalance_ = _getMBalanceOf(sender_, currentMIndex_);

        // Adjust wrap amount if sender balance at currentMIndex_ is less than the wrap amount
        if (wrapAmount_ > senderMBalance_) {
            wrapAmount_ = bound(wrapAmount_, 0, senderMBalance_);
        }

        if (wrapAmount_ == 0) return;

        uint256 usualMMTokenBalanceBefore_ = _mToken.balanceOf(address(_usualM));

        // Only set mint cap if newly wrap amount will exceed the current cap
        if ((usualMMTokenBalanceBefore_ + wrapAmount_) > _usualM.mintCap()) {
            _setMintCap(usualMMTokenBalanceBefore_ + wrapAmount_ + 1);
        }

        uint256 senderMTokenBalanceBefore_ = _mToken.balanceOf(sender_);
        uint256 recipientUsualMBalanceBefore_ = _usualM.balanceOf(recipient_);

        vm.prank(sender_);
        _mToken.approve(address(_usualM), wrapAmount_);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IUsualM.InvalidAmount.selector));
        } else {
            vm.expectEmit();

            // UsualM tranfer/mint event
            emit IERC20Like.Transfer(address(0), recipient_, wrapAmount_);
        }

        vm.prank(sender_);
        _usualM.wrap(recipient_, wrapAmount_);

        if (senderEarning_) {
            assertEq(_mToken.balanceOf(sender_), senderMTokenBalanceBefore_ - wrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ + wrapAmount_, 1); // May round down in favor of the protocol

            assertEq(_usualM.balanceOf(recipient_), recipientUsualMBalanceBefore_ + wrapAmount_);
        } else {
            assertEq(_mToken.balanceOf(sender_), senderMTokenBalanceBefore_ - wrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ + wrapAmount_, 1); // May round down in favor of the protocol

            assertEq(_usualM.balanceOf(recipient_), recipientUsualMBalanceBefore_ + wrapAmount_);
        }
    }

    /* ============ unwrap ============ */
    function test_unwrap_fromEarnerToEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(_USUAL_M_PROXY);

        _wrap(_earner, _earner, wrapAmount_);

        uint256 mTokenBalanceOfEarner_ = _mToken.balanceOf(_earner);
        uint256 usualMBalanceOfEarner_ = _usualM.balanceOf(_earner);

        assertEq(mTokenBalanceOfEarner_, wrapAmount_);
        assertEq(usualMBalanceOfEarner_, wrapAmount_);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ += (wrapAmount_ - 1)); // May round down in favor of the protocol

        _unwrap(_earner, _earner, unwrapAmount_);

        assertEq(_mToken.balanceOf(_earner), 10e6);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ -= unwrapAmount_);

        assertEq(_usualM.balanceOf(_earner), 0);
    }

    function test_unwrap_fromEarnerToNonEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(_USUAL_M_PROXY);

        _wrap(_earner, _earner, wrapAmount_);

        uint256 mTokenBalanceOfEarner_ = _mToken.balanceOf(_earner);
        uint256 usualMBalanceOfEarner_ = _usualM.balanceOf(_earner);

        assertEq(mTokenBalanceOfEarner_, wrapAmount_);
        assertEq(usualMBalanceOfEarner_, wrapAmount_);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ += (wrapAmount_ - 1)); // May round down in favor of the protocol

        _unwrap(_earner, _nonEarner, unwrapAmount_);

        assertEq(_mToken.balanceOf(_earner), unwrapAmount_);
        assertEq(_mToken.balanceOf(_nonEarner), 15e6);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ -= unwrapAmount_);

        assertEq(_usualM.balanceOf(_earner), 0);
    }

    function test_unwrap_fromNonEarnerToNonEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(_USUAL_M_PROXY);

        _wrap(_nonEarner, _nonEarner, wrapAmount_);

        assertEq(_mToken.balanceOf(_nonEarner), wrapAmount_);
        assertEq(_usualM.balanceOf(_nonEarner), wrapAmount_);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ += (wrapAmount_ - 1)); // May round down in favor of the protocol

        _unwrap(_nonEarner, _nonEarner, unwrapAmount_);
        mTokenBalanceOfUsualM_ -= unwrapAmount_;

        assertEq(_mToken.balanceOf(_nonEarner), 10e6);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_, 1); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 0);
    }

    function test_unwrap_fromNonEarnerToEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(_USUAL_M_PROXY);

        _wrap(_nonEarner, _nonEarner, wrapAmount_);

        assertEq(_mToken.balanceOf(_nonEarner), wrapAmount_);
        assertEq(_usualM.balanceOf(_nonEarner), wrapAmount_);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ += (wrapAmount_ - 1)); // May round down in favor of the protocol

        _unwrap(_nonEarner, _earner, unwrapAmount_);

        assertEq(_mToken.balanceOf(_nonEarner), wrapAmount_);
        assertEq(_mToken.balanceOf(_earner), 10e6 + unwrapAmount_);
        assertEq(_mToken.balanceOf(address(_usualM)), mTokenBalanceOfUsualM_ -= unwrapAmount_);

        assertEq(_usualM.balanceOf(_nonEarner), 0);
        assertEq(_usualM.balanceOf(_earner), 0);
    }

    function testFuzz_unwrap(
        bool senderEarning_,
        bool recipientEarning_,
        uint256 wrapAmount_,
        uint256 unwrapAmount_,
        uint128 currentMIndex_
    ) external {
        currentMIndex_ = uint128(bound(currentMIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        _mockCurrentMIndex(currentMIndex_);

        wrapAmount_ = bound(wrapAmount_, 0, _mToken.balanceOf(_mTokenSource));
        if (wrapAmount_ == 0) return;

        address sender_ = senderEarning_ ? _earner : _nonEarner;
        address recipient_ = recipientEarning_ ? _earner : _nonEarner;

        _giveMToken(sender_, wrapAmount_);

        uint256 senderMBalance_ = _getMBalanceOf(sender_, currentMIndex_);

        // Adjust wrap amount if sender balance at currentMIndex_ is less than the wrap amount
        if (wrapAmount_ > senderMBalance_) {
            wrapAmount_ = bound(wrapAmount_, 0, senderMBalance_);
        }

        if (wrapAmount_ == 0) return;

        uint256 usualMMTokenBalanceBefore_ = _mToken.balanceOf(address(_usualM));

        // // Only set mint cap if wrap amount is different from current cap
        // if (wrapAmount_ != _usualM.mintCap()) {
        //     _setMintCap(wrapAmount_);
        // }

        // Only set mint cap if newly wrap amount will exceed the current cap
        if ((usualMMTokenBalanceBefore_ + wrapAmount_) > _usualM.mintCap()) {
            _setMintCap(usualMMTokenBalanceBefore_ + wrapAmount_ + 1);
        }

        unwrapAmount_ = bound(unwrapAmount_, 0, wrapAmount_);

        _wrap(sender_, sender_, wrapAmount_);
        usualMMTokenBalanceBefore_ += wrapAmount_;

        uint256 senderUsualMBalanceBefore_ = _usualM.balanceOf(sender_);
        uint256 recipientMTokenBalanceBefore_ = _mToken.balanceOf(recipient_);

        if (unwrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IUsualM.InvalidAmount.selector));
        } else if (unwrapAmount_ > usualMMTokenBalanceBefore_) {
            // Reverts with IMToken.InsufficientBalance due to lack of excess M
            vm.expectRevert();
        } else {
            vm.expectEmit(address(_usualM));
            emit IERC20Like.Transfer(address(sender_), address(0), unwrapAmount_); // UsualM burn event

            vm.expectEmit(address(_mToken));
            emit IERC20Like.Transfer(address(_usualM), recipient_, unwrapAmount_); // M token transfer event
        }

        _unwrap(sender_, recipient_, unwrapAmount_);

        if (unwrapAmount_ == 0 || unwrapAmount_ > usualMMTokenBalanceBefore_) return;

        if (recipientEarning_) {
            assertEq(_mToken.balanceOf(recipient_), recipientMTokenBalanceBefore_ + unwrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ - unwrapAmount_, 2); // May round down in favor of the protocol
        } else {
            assertEq(_mToken.balanceOf(recipient_), recipientMTokenBalanceBefore_ + unwrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ - unwrapAmount_, 2); // May round down in favor of the protocol
        }

        assertEq(_usualM.balanceOf(sender_), senderUsualMBalanceBefore_ - unwrapAmount_);
    }

    /* ============ upgrade ============ */

    function test_upgrade() external {
        // Check storage layout
        assertEq(_usualM.mToken(), _M_TOKEN);
        assertEq(_usualM.yieldRecipient(), _USUAL_M_YIELD_RECIPIENT);

        // Check balances after unwrapping
        assertApproxEqAbs(_mToken.balanceOf(_USUAL_M_PROXY), _wrappedMTokenBalanceBeforeUpgrade, 1); // May round down on unwrap
        assertEq(_wrappedM.balanceOf(_USUAL_M_PROXY), 0);
    }

    /* ============ mock calls ============ */

    function _mockCurrentMIndex(uint128 mIndex_) internal {
        bytes[] memory mocks_ = new bytes[](1);
        mocks_[0] = abi.encode(mIndex_);

        vm.mockCalls(address(_mToken), abi.encodeWithSelector(IMTokenLike.currentIndex.selector), mocks_);
    }

    /* ============ utils ============ */

    /// @dev Helper to get the M balance of account_ if account_ is not an earner,
    ///      otherwise, get the balance of account_ at mIndex_.
    function _getMBalanceOf(address account_, uint128 mIndex_) internal view returns (uint256) {
        return
            _mToken.isEarning(account_)
                ? (_mToken.principalBalanceOf(account_) * mIndex_) / _EXP_SCALED_ONE
                : _mToken.balanceOf(account_);
    }

    function _giveMToken(address account_, uint256 amount_) internal {
        vm.prank(_mTokenSource);
        _mToken.transfer(account_, amount_);
    }

    function _fundAccounts() internal {
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _giveMToken(_accounts[i], 10e6);
            vm.deal(_accounts[i], 0.1 ether);
        }
    }

    function _grantRoles() internal {
        for (uint256 i = 0; i < _accounts.length; ++i) {
            vm.prank(_USUAL_ADMIN);
            IRegistryAccess(_USUAL_REGISTRY_ACCESS).grantRole(USUAL_M_UNWRAP, _accounts[i]);
        }

        vm.prank(_USUAL_ADMIN);
        IRegistryAccess(_USUAL_REGISTRY_ACCESS).grantRole(USUAL_M_MINTCAP_ALLOCATOR, _USUAL_ADMIN);
    }

    function _startEarningM(address account_) internal {
        vm.prank(account_);
        _mToken.startEarning();
    }

    function _setMintCap(uint256 newMintCap_) internal {
        vm.prank(_USUAL_ADMIN);
        _usualM.setMintCap(newMintCap_);
    }

    function _wrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _mToken.approve(address(_usualM), amount_);

        vm.prank(account_);
        _usualM.wrap(recipient_, amount_);
    }

    function _unwrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _usualM.unwrap(recipient_, amount_);
    }

    function _wrapWithPermitVRS(
        address account_,
        uint256 signerPrivateKey_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_,
        uint256 deadline_
    ) internal {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getPermit(account_, signerPrivateKey_, amount_, nonce_, deadline_);

        vm.prank(account_);
        _usualM.wrapWithPermit(recipient_, amount_, deadline_, v_, r_, s_);
    }

    function _getPermit(
        address account_,
        uint256 signerPrivateKey_,
        uint256 amount_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return
            vm.sign(
                signerPrivateKey_,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        _mToken.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                _mToken.PERMIT_TYPEHASH(),
                                account_,
                                address(_usualM),
                                amount_,
                                nonce_,
                                deadline_
                            )
                        )
                    )
                )
            );
    }
}
