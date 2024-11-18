// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../lib/forge-std/src/Test.sol";

import { TestBase } from "./TestBase.sol";

contract UCTokenIntegrationTests is TestBase {
    function setUp() external {
        _deployComponents();
        _fundAccounts();
        _grantRoles();

        // Add UCToken to the list of earners
        _setClaimOverrideRecipient(address(_ucToken), _treasury);
        // Add treasury as a recipient of UCToken yield
        _addToList(_EARNERS_LIST, address(_ucToken));
        _smartMToken.startEarningFor(address(_ucToken));
    }

    function test_integration_constants() external view {
        assertEq(_ucToken.name(), "UCToken");
        assertEq(_ucToken.symbol(), "UCT");
        assertEq(_ucToken.decimals(), 18);
        assertEq(_smartMToken.isEarning(address(_ucToken)), true);
        assertEq(_smartMToken.claimOverrideRecipientFor(address(_ucToken)), _treasury);
    }

    function test_yieldAccumulationAndClaim() external {
        uint256 amount = 10e6;

        vm.prank(_alice);
        _smartMToken.approve(address(_ucToken), amount);

        vm.prank(_alice);
        _ucToken.wrap(_alice, amount);

        // Check balances of UCToken and Alice after wrapping
        assertEq(_ucToken.balanceOf(_alice), amount * 1e12);
        assertEq(_smartMToken.balanceOf(address(_ucToken)), amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        uint256 yield = _smartMToken.accruedYieldOf(address(_ucToken));
        assertGt(yield, 0);

        // Claim yield by unwrapping
        vm.prank(_alice);
        _ucToken.unwrap(_alice);

        // Check balances of UCToken and Alice after unwrapping
        assertEq(_ucToken.balanceOf(_alice), 0);
        assertEq(_smartMToken.balanceOf(address(_ucToken)), 0);
        assertEq(_smartMToken.balanceOf(_alice), amount);

        assertEq(_smartMToken.balanceOf(_treasury), yield);

        vm.prank(_bob);
        _smartMToken.approve(address(_ucToken), amount);

        vm.prank(_bob);
        _ucToken.wrap(_bob, amount);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        yield += _smartMToken.accruedYieldOf(address(_ucToken));

        // Explicitly claim yield for UCToken
        _smartMToken.claimFor(address(_ucToken));

        assertEq(_smartMToken.accruedYieldOf(address(_ucToken)), 0);
        assertEq(_smartMToken.balanceOf(_treasury), yield);
    }
}
