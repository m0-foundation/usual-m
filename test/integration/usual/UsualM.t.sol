// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Test.sol";
import { Vm } from "../../../lib/forge-std/src/Vm.sol";

import { ProxyAdmin } from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC1967Utils } from "../../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

import { UsualM } from "../../../src/usual/UsualM.sol";

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
        _deployComponents();
        _fundAccounts();
        _grantRoles();

        // Add UsualM to the list of earners
        _addToList(_EARNERS_LIST, address(_usualM));

        // Add Usual treasury to the list of earners
        _addToList(_EARNERS_LIST, _treasury);

        vm.prank(_admin);
        _usualM.startEarningM();

        vm.prank(_treasury);
        _mToken.startEarning();

        // Set Mint Cap
        vm.prank(_admin);
        _usualM.setMintCap(10_000e6);
    }

    function test_integration_constants() external view {
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_mToken.isEarning(address(_usualM)), true);
        assertEq(_mToken.isEarning(_treasury), true);
    }

    function test_yieldAccumulationAndClaim() external {
        uint256 amount = 10e6;

        _wrap(_alice, _alice, amount);

        // Check balances of UsualM and Alice after wrapping
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_mToken.balanceOf(address(_usualM)), amount - 1); // M token rounds down for an earner

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        uint256 yield = _usualM.excessM();
        assertGt(yield, 0);

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

        yield = _usualM.excessM();

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
        assertEq(_mToken.balanceOf(_treasury), yield);
        assertApproxEqAbs(_mToken.balanceOf(address(_usualM)), amount, 1); // excessM rounds down and a 1 wei buffer is left after claiming excess
        assertEq(_usualM.excessM(), 0);
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
