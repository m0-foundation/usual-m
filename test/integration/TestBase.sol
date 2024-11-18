// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { Test, console2 } from "../../lib/forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy
} from "../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ISmartMTokenLike } from "../../src/token/interfaces/ISmartMTokenLike.sol";
import { IRegistrarLike } from "../utils/IRegistrarLike.sol";
import { IUCToken } from "../../src/token/interfaces/IUCToken.sol";
import { IRegistryAccess } from "../../src/token/interfaces/IRegistryAccess.sol";

import { UCToken } from "../../src/token/UCToken.sol";
import { RegistryAccess } from "../utils/RegistryAccess.sol";

import { UCT_UNWRAP, UCT_PAUSE_UNPAUSE } from "../../src/token/constants.sol";

contract TestBase is Test {
    address internal constant _standardGovernor = 0xB024aC5a7c6bC92fbACc8C3387E628a07e1Da016;
    address internal constant _registrar = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;

    bytes32 internal constant _EARNERS_LIST = "earners";
    bytes32 internal constant _CLAIM_OVERRIDE_RECIPIENT_PREFIX = "wm_claim_override_recipient";

    ISmartMTokenLike internal constant _smartMToken = ISmartMTokenLike(0x437cc33344a0B27A429f795ff6B469C72698B291);

    // Large SmartM holder on Ethereum Mainnet
    address internal constant _smartMSource = 0x970A7749EcAA4394C8B2Bf5F2471F41FD6b79288;

    address internal _admin = makeAddr("admin");
    address internal _treasury = makeAddr("treasury");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eric = makeAddr("eric");
    address internal _frank = makeAddr("frank");
    address internal _grace = makeAddr("grace");
    address internal _henry = makeAddr("henry");
    address internal _ivan = makeAddr("ivan");
    address internal _judy = makeAddr("judy");

    uint256 internal _aliceKey = _makeKey("alice");

    address[] internal _accounts = [_alice, _bob, _carol, _dave, _eric, _frank, _grace, _henry, _ivan, _judy];

    address internal _registryAccessImplementation;
    address internal _registryAccess;
    address internal _ucTokenImplementation;
    IUCToken internal _ucToken;

    function _addToList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).addToList(list_, account_);
    }

    function _removeFomList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).removeFromList(list_, account_);
    }

    function _giveSmartM(address account_, uint256 amount_) internal {
        vm.prank(_smartMSource);
        _smartMToken.transfer(account_, amount_);
    }

    function _giveEth(address account_, uint256 amount_) internal {
        vm.deal(account_, amount_);
    }

    function _wrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _smartMToken.approve(address(_ucToken), amount_);

        vm.prank(account_);
        _ucToken.wrap(recipient_, amount_);
    }

    function _wrap(address account_, address recipient_) internal {
        vm.prank(account_);
        _smartMToken.approve(address(_ucToken), type(uint256).max);

        vm.prank(account_);
        _ucToken.wrap(recipient_);
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
        _ucToken.wrapWithPermit(recipient_, amount_, deadline_, v_, r_, s_);
    }

    function _unwrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _ucToken.unwrap(recipient_, amount_);
    }

    function _unwrap(address account_, address recipient_) internal {
        vm.prank(account_);
        _ucToken.unwrap(recipient_);
    }

    function _set(bytes32 key_, bytes32 value_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).setKey(key_, value_);
    }

    function _setClaimOverrideRecipient(address account_, address recipient_) internal {
        _set(keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_PREFIX, account_)), bytes32(uint256(uint160(recipient_))));
    }

    function _deployComponents() internal {
        _registryAccessImplementation = address(new RegistryAccess());
        bytes memory registryData = abi.encodeWithSignature("initialize(address)", _admin);
        _registryAccess = address(new TransparentUpgradeableProxy(_registryAccessImplementation, _admin, registryData));

        _ucTokenImplementation = address(new UCToken());
        bytes memory ucTokenData = abi.encodeWithSignature(
            "initialize(address,address)",
            address(_smartMToken),
            _registryAccess
        );
        _ucToken = IUCToken(address(new TransparentUpgradeableProxy(_ucTokenImplementation, _admin, ucTokenData)));
    }

    function _fundAccounts() internal {
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _giveSmartM(_accounts[i], 10e6);
            _giveEth(_accounts[i], 0.1 ether);
        }
    }

    function _grantRoles() internal {
        vm.prank(_admin);
        IRegistryAccess(_registryAccess).grantRole(UCT_PAUSE_UNPAUSE, _admin);

        for (uint256 i = 0; i < _accounts.length; ++i) {
            vm.prank(_admin);
            IRegistryAccess(_registryAccess).grantRole(UCT_UNWRAP, _accounts[i]);
        }
    }

    /* ============ utils ============ */

    function _makeKey(string memory name_) internal returns (uint256 key_) {
        (, key_) = makeAddrAndKey(name_);
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
                        _smartMToken.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                _smartMToken.PERMIT_TYPEHASH(),
                                account_,
                                address(_smartMToken),
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
