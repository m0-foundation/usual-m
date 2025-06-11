// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import { IProxyAdmin } from "../../../lib/openzeppelin-foundry-upgrades/src/internal/interfaces/IProxyAdmin.sol";

import { IMTokenLike } from "../../../src/usual/interfaces/IMTokenLike.sol";
import { IWrappedMLike } from "../../../src/usual/interfaces/IWrappedMLike.sol";
import { IUsualMV2 } from "../../../src/usual/interfaces/IUsualMV2.sol";

import { UpgradeUsualMBase } from "../../../script/upgrade/UpgradeUsualMBase.sol";

contract UsualMV2UpgradeIntegrationTests is Test, UpgradeUsualMBase {
    address internal constant _USUAL_ADMIN = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7; // Usual default admin
    address internal constant _USUAL_REGISTRY_ACCESS = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56;
    address internal constant _USUAL_TREASURY = 0xdd82875f0840AAD58a455A70B88eEd9F59ceC7c7;
    address internal constant _WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    IMTokenLike internal constant _mToken = IMTokenLike(_M_TOKEN);
    IWrappedMLike internal constant _wrappedM = IWrappedMLike(_WRAPPED_M_TOKEN);

    IUsualMV2 internal _usualM;

    uint256 internal _wrappedMTokenBalanceBeforeUpgrade;

    uint256 public mainnetFork;

    function setUp() external {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"), 22_625_475);

        _wrappedMTokenBalanceBeforeUpgrade = _wrappedM.balanceOf(_USUAL_M_PROXY);

        _usualM = IUsualMV2(_USUAL_M_PROXY);

        // Check balances before unwrapping
        assertEq(_mToken.balanceOf(_USUAL_M_PROXY), 0);
        assertEq(_wrappedM.balanceOf(_USUAL_M_PROXY), _wrappedMTokenBalanceBeforeUpgrade);
    }

    function test_upgradeViaProxyAdmin_interface() external {
        address usualMV2Implementation_ = _prepareUsualMUpgrade();

        vm.startPrank(_USUAL_ADMIN);

        IProxyAdmin(_getAdminAddress(_USUAL_M_PROXY)).upgradeAndCall(
            _USUAL_M_PROXY,
            usualMV2Implementation_,
            _getInitializeV2Calldata()
        );

        vm.stopPrank();

        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_usualM.registryAccess(), _USUAL_REGISTRY_ACCESS);
        assertEq(_usualM.mToken(), _M_TOKEN);
        assertEq(_usualM.yieldRecipient(), _USUAL_M_YIELD_RECIPIENT);
    }

    function test_upgradeViaProxyAdmin_calldata() external {
        address usualMV2Implementation_ = _prepareUsualMUpgrade();

        vm.startPrank(_USUAL_ADMIN);

        _getAdminAddress(_USUAL_M_PROXY).call(_getUpgradeAndCallCalldata(usualMV2Implementation_));

        vm.stopPrank();

        assertEq(_usualM.name(), "UsualM");
        assertEq(_usualM.symbol(), "USUALM");
        assertEq(_usualM.decimals(), 6);
        assertEq(_usualM.registryAccess(), _USUAL_REGISTRY_ACCESS);
        assertEq(_usualM.mToken(), _M_TOKEN);
        assertEq(_usualM.yieldRecipient(), _USUAL_M_YIELD_RECIPIENT);
    }
}
