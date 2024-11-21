// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Test.sol";

import { TestBase } from "./TestBase.sol";

contract UsualMIntegrationTests is TestBase {
    function setUp() external {
        _deployComponents();
        _fundAccounts();
        _grantRoles();

        // Add UsualM to the list of earners
        _setClaimOverrideRecipient(address(_usualM), _treasury);
        // Add treasury as a recipient of UsualM yield
        _addToList(_EARNERS_LIST, address(_usualM));
        _smartMToken.startEarningFor(address(_usualM));
    }

    function test_integration_constants() external view {
        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_smartMToken.isEarning(address(_usualM)), true);
        assertEq(_smartMToken.claimOverrideRecipientFor(address(_usualM)), _treasury);
    }

    function test_yieldAccumulationAndClaim() external {
        uint256 amount = 10e6;

        vm.prank(_alice);
        _smartMToken.approve(address(_usualM), amount);

        vm.prank(_alice);
        _usualM.wrap(_alice, amount);

        // Check balances of UsualM and Alice after wrapping
        assertEq(_usualM.balanceOf(_alice), amount);
        assertEq(_smartMToken.balanceOf(address(_usualM)), amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        uint256 yield = _smartMToken.accruedYieldOf(address(_usualM));
        assertGt(yield, 0);

        // Claim yield by unwrapping
        vm.prank(_alice);
        _usualM.unwrap(_alice);

        // Check balances of UsualM and Alice after unwrapping
        assertEq(_usualM.balanceOf(_alice), 0);
        assertEq(_smartMToken.balanceOf(address(_usualM)), 0);
        assertEq(_smartMToken.balanceOf(_alice), amount);

        assertEq(_smartMToken.balanceOf(_treasury), yield);

        vm.prank(_bob);
        _smartMToken.approve(address(_usualM), amount);

        vm.prank(_bob);
        _usualM.wrap(_bob, amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        yield += _smartMToken.accruedYieldOf(address(_usualM));

        // Explicitly claim yield for UsualM
        _smartMToken.claimFor(address(_usualM));

        assertEq(_smartMToken.accruedYieldOf(address(_usualM)), 0);
        assertEq(_smartMToken.balanceOf(_treasury), yield);
    }
}
