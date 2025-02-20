// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Vm } from "../../../lib/forge-std/src/Vm.sol";

import { ProxyAdmin } from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC1967Utils } from "../../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import { UsualM } from "../../../src/usual/UsualM.sol";

import { IUsualM } from "../../../src/usual/interfaces/IUsualM.sol";

import { IERC20Like } from "../../utils/IERC20Like.sol";

import { TestBase } from "./TestBase.sol";

// Required for testing UsualM upgradeability
contract V2 {
    function initializeV2Test() public {}

    function version() public pure returns (uint256) {
        return 2;
    }
}

contract UsualMV2 is UsualM, V2 {}

contract UsualMIntegrationTests is TestBase {
    function setUp() external {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"), 21_719_303);

        _deployComponents();
        _fundAccounts();
        _grantRoles();

        // Add UsualM to the list of earners and start earning M
        _addToList(_EARNERS_LIST, address(_usualM));

        vm.prank(_admin);
        _usualM.startEarningM();

        // Add Usual treasury to the list of earners and start earning M
        _addToList(_EARNERS_LIST, _treasury);
        _startEarningM(_treasury);

        // Add earner account to earners list and start earning M
        _addToList(_EARNERS_LIST, _earner);
        _startEarningM(_earner);

        // Set Mint Cap
        _setMintCap(10_000e6);
    }

    /* ============ constants ============ */

    function test_integration_constants() external {
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_mToken.isEarning(address(_usualM)), true);
        assertEq(_mToken.isEarning(_treasury), true);
    }

    /* ============ yield ============ */

    function test_yieldAccumulationAndClaim() external {
        uint256 amount = 10e6;

        _wrap(_alice, _alice, amount);

        // Check balances of UsualM and Alice after wrapping
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(address(_usualM)), amount - 1); // M token rounds down for an earner

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        int248 excessM = _usualM.excessM();
        assertGt(excessM, 0);

        uint240 yield = uint240(int240(excessM));

        // Check balances before unwrapping Usual M
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(_treasury), 0);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), amount + yield, 1); // excessM rounds down

        // Unwrap UsualM
        _unwrap(_alice, _alice, amount);

        // Check balances after unwrapping
        assertEq(_usualM.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(_treasury), 0);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), yield, 1);

        _wrap(_bob, _bob, amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        excessM = _usualM.excessM();
        assertGt(excessM, 0);

        yield = uint240(int240(excessM));

        // Check balances before claiming excess M
        assertEq(_usualM.balanceOf(_bob), amount);
        assertEq(_mToken.balanceOf(_bob), 0);
        assertEq(_mToken.balanceOf(_treasury), 0);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), amount + yield, 2);

        vm.prank(_admin);
        _usualM.claimExcessM(_treasury);

        // Check balances after claiming excess M
        assertEq(_usualM.balanceOf(_bob), amount);
        assertEq(_mToken.balanceOf(_bob), 0);
        assertApproxEqAbs(_mToken.balanceOf(_treasury), yield, 1); // May round down in favor of the protocol if any rounding errors occured
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), amount, 2); // excessM rounds down by 1 wei and a 2 wei buffer is left after claiming excess to account for the rounding error
        assertEq(_usualM.excessM(), 0);
    }

    /* ============ wrap ============ */

    function test_wrap_fromEarnerToEarner() external {
        uint256 wrapAmount_ = 5e6;

        _wrap(_earner, _earner, wrapAmount_);

        assertApproxEqAbs(_mToken.balanceOf(_earner), wrapAmount_, 1); // May round down in favor of the protocol
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), wrapAmount_, 1); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_earner), wrapAmount_);
    }

    function test_wrap_fromEarnerToNonEarner() external {
        uint256 wrapAmount_ = 5e6;

        _wrap(_earner, _nonEarner, wrapAmount_);

        assertApproxEqAbs(_mToken.balanceOf(_earner), wrapAmount_, 1); // May round down in favor of the protocol
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), wrapAmount_, 1); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_earner), 0);
        assertEq(_usualM.balanceOf(_nonEarner), wrapAmount_);
    }

    function test_wrap_fromNonEarnerToNonEarner() external {
        _wrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), 5e6, 1); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 5e6);
    }

    function test_wrap_fromNonEarnerToEarner() external {
        _wrap(_nonEarner, _earner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), 5e6, 1); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 0);
        assertEq(_usualM.balanceOf(_earner), 5e6);
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
        currentMIndex_ = uint128(bound(currentMIndex_, EXP_SCALED_ONE, 10 * EXP_SCALED_ONE));
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

        // Only set mint cap if wrap amount is different from current cap
        if (wrapAmount_ != _usualM.mintCap()) {
            _setMintCap(wrapAmount_);
        }

        uint256 senderMTokenBalanceBefore_ = _mToken.balanceOf(sender_);
        uint256 usualMMTokenBalanceBefore_ = _mToken.balanceOf(address(_usualM));
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
            assertApproxEqAbs(_mToken.balanceOf(sender_), senderMTokenBalanceBefore_ - wrapAmount_, 10); // May round down in favor of the protocol
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ + wrapAmount_, 10); // May round up in favor of UsualM

            assertEq(_usualM.balanceOf(recipient_), recipientUsualMBalanceBefore_ + wrapAmount_);
        } else {
            assertEq(_mToken.balanceOf(sender_), senderMTokenBalanceBefore_ - wrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ + wrapAmount_, 2); // May round down in favor of the protocol

            assertEq(_usualM.balanceOf(recipient_), recipientUsualMBalanceBefore_ + wrapAmount_);
        }
    }

    /* ============ unwrap ============ */
    function test_unwrap_fromEarnerToEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;

        _wrap(_earner, _earner, wrapAmount_);

        uint256 mTokenBalanceOfEarner_ = _mToken.balanceOf(_earner);
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(address(_usualM));
        uint256 usualMBalanceOfEarner_ = _usualM.balanceOf(_earner);

        assertApproxEqAbs(mTokenBalanceOfEarner_, wrapAmount_, 1); // May round down in favor of the protocol
        assertEq(usualMBalanceOfEarner_, wrapAmount_);
        assertApproxEqAbs(mTokenBalanceOfUsualM_, wrapAmount_, 1); // May round down in favor of the protocol

        // Due to rounding down in favor of the protocol, there may be 1 wei less M token in UsualM
        if (usualMBalanceOfEarner_ > mTokenBalanceOfUsualM_) {
            unwrapAmount_ = mTokenBalanceOfUsualM_;
        }

        _unwrap(_earner, _earner, unwrapAmount_);

        assertApproxEqAbs(_mToken.balanceOf(_earner), 10e6, 1); // May round down in favor of the protocol
        assertEq(_mToken.balanceOf(address(_usualM)), 0);

        assertApproxEqAbs(_usualM.balanceOf(_earner), 0, 1); // May not be able to unwrap the full amount if M rounded down
    }

    function test_unwrap_fromEarnerToNonEarner() external {
        uint256 wrapAmount_ = 5e6;
        uint256 unwrapAmount_ = wrapAmount_;

        _wrap(_earner, _earner, wrapAmount_);

        uint256 mTokenBalanceOfEarner_ = _mToken.balanceOf(_earner);
        uint256 mTokenBalanceOfUsualM_ = _mToken.balanceOf(address(_usualM));
        uint256 usualMBalanceOfEarner_ = _usualM.balanceOf(_earner);

        assertApproxEqAbs(mTokenBalanceOfEarner_, wrapAmount_, 1); // May round down in favor of the protocol
        assertEq(usualMBalanceOfEarner_, wrapAmount_);
        assertApproxEqAbs(mTokenBalanceOfUsualM_, wrapAmount_, 1); // May round down in favor of the protocol

        // Due to rounding down in favor of the protocol, there may be 1 wei less M token in UsualM
        if (usualMBalanceOfEarner_ > mTokenBalanceOfUsualM_) {
            unwrapAmount_ = mTokenBalanceOfUsualM_;
        }

        _unwrap(_earner, _nonEarner, unwrapAmount_);

        assertApproxEqAbs(_mToken.balanceOf(_earner), unwrapAmount_, 1); // May round down in favor of the protocol
        assertApproxEqAbs(_mToken.balanceOf(_nonEarner), 15e6, 1); // May not be able to unwrap the full amount if M rounded down
        assertEq(_mToken.balanceOf(address(_usualM)), 0);

        assertApproxEqAbs(_usualM.balanceOf(_earner), 0, 1); // May not be able to unwrap the full amount if M rounded down
    }

    function test_unwrap_fromNonEarnerToNonEarner() external {
        _wrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertEq(_usualM.balanceOf(_nonEarner), 5e6);

        // Add some excess M
        _wrap(_alice, _alice, 1e6);

        _unwrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 10e6);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), 1e6, 2); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 0);
    }

    function test_unwrap_fromNonEarnerToNonEarner_noExcess() external {
        _wrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertEq(_usualM.balanceOf(_nonEarner), 5e6);

        // Reverts with IMToken.InsufficientBalance due to lack of excess M
        vm.expectRevert();
        _unwrap(_nonEarner, _nonEarner, 5e6);
    }

    function test_unwrap_fromNonEarnerToEarner() external {
        _wrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertEq(_usualM.balanceOf(_nonEarner), 5e6);

        // Add some excess M
        _wrap(_alice, _alice, 1e6);

        _unwrap(_nonEarner, _earner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertApproxEqAbs(_mToken.balanceOf(_earner), 15e6, 2); // May round down in favor of the protocol
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), 1e6, 3); // May round down in favor of the protocol

        assertEq(_usualM.balanceOf(_nonEarner), 0);
        assertEq(_usualM.balanceOf(_earner), 0);
    }

    function test_unwrap_fromNonEarnerToEarner_noExcess() external {
        _wrap(_nonEarner, _nonEarner, 5e6);

        assertEq(_mToken.balanceOf(_nonEarner), 5e6);
        assertEq(_usualM.balanceOf(_nonEarner), 5e6);

        // Reverts with IMToken.InsufficientBalance due to lack of excess M
        vm.expectRevert();
        _unwrap(_nonEarner, _earner, 5e6);
    }

    function testFuzz_unwrap(
        bool senderEarning_,
        bool recipientEarning_,
        uint256 wrapAmount_,
        uint256 unwrapAmount_,
        uint128 currentMIndex_
    ) external {
        currentMIndex_ = uint128(bound(currentMIndex_, EXP_SCALED_ONE, 10 * EXP_SCALED_ONE));
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

        // Only set mint cap if wrap amount is different from current cap
        if (wrapAmount_ != _usualM.mintCap()) {
            _setMintCap(wrapAmount_);
        }

        unwrapAmount_ = bound(unwrapAmount_, 0, wrapAmount_);

        _wrap(sender_, sender_, wrapAmount_);

        uint256 senderUsualMBalanceBefore_ = _usualM.balanceOf(sender_);
        uint256 usualMMTokenBalanceBefore_ = _mToken.balanceOf(address(_usualM));
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
            assertApproxEqAbs(_mToken.balanceOf(recipient_), recipientMTokenBalanceBefore_ + unwrapAmount_, 2); // May round up in favor of the recipient
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ - unwrapAmount_, 2); // May round down in favor of the protocol
        } else {
            assertEq(_mToken.balanceOf(recipient_), recipientMTokenBalanceBefore_ + unwrapAmount_);
            assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), usualMMTokenBalanceBefore_ - unwrapAmount_, 2); // May round down in favor of the protocol
        }

        assertEq(_usualM.balanceOf(sender_), senderUsualMBalanceBefore_ - unwrapAmount_);
    }

    /* ============ upgrade ============ */

    function test_upgrade() external {
        address usualMV2 = address(new UsualMV2());

        address proxyAdmin = _getAdminAddress(address(_usualM));

        vm.prank(_admin);
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(address(_usualM)),
            usualMV2,
            abi.encodeWithSelector(V2.initializeV2Test.selector)
        );

        assertEq(V2(address(_usualM)).version(), 2);
    }

    function _getAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
