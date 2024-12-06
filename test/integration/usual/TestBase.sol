// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../../../lib/forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy
} from "../../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { IRegistrarLike } from "../../utils/IRegistrarLike.sol";
import { IWrappedMLike } from "../../../src/usual/interfaces/IWrappedMLike.sol";
import { IUsualM } from "../../../src/usual/interfaces/IUsualM.sol";
import { IRegistryAccess } from "../../../src/usual/interfaces/IRegistryAccess.sol";

import { UsualM } from "../../../src/usual/UsualM.sol";

import { USUAL_M_UNWRAP, USUAL_M_PAUSE, USUAL_M_UNPAUSE, USUAL_M_MINTCAP_ALLOCATOR } from "../../../src/usual/constants.sol";

contract TestBase is Test {
    address internal constant _standardGovernor = 0xB024aC5a7c6bC92fbACc8C3387E628a07e1Da016;
    address internal constant _registrar = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;

    bytes32 internal constant _EARNERS_LIST = "earners";
    bytes32 internal constant _CLAIM_OVERRIDE_RECIPIENT_PREFIX = "wm_claim_override_recipient";

    IWrappedMLike internal constant _wrappedM = IWrappedMLike(0x437cc33344a0B27A429f795ff6B469C72698B291);

    // Large WrappedM holder on Ethereum Mainnet
    address internal constant _wrappedMSource = 0x970A7749EcAA4394C8B2Bf5F2471F41FD6b79288;

    IRegistryAccess internal constant _registryAccess = IRegistryAccess(0x0D374775E962c3608B8F0A4b8B10567DF739bb56);
    address internal _admin = _registryAccess.defaultAdmin();

    address internal _treasury = makeAddr("treasury");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");

    uint256 internal _aliceKey = _makeKey("alice");

    address[] internal _accounts = [_alice, _bob, _carol];

    address internal _usualMImplementation;
    IUsualM internal _usualM;

    function _addToList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).addToList(list_, account_);
    }

    function _removeFomList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).removeFromList(list_, account_);
    }

    function _giveWrappedM(address account_, uint256 amount_) internal {
        vm.prank(_wrappedMSource);
        _wrappedM.transfer(account_, amount_);
    }

    function _giveEth(address account_, uint256 amount_) internal {
        vm.deal(account_, amount_);
    }

    function _wrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _wrappedM.approve(address(_usualM), amount_);

        vm.prank(account_);
        _usualM.wrap(recipient_, amount_);
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

    function _unwrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _usualM.unwrap(recipient_, amount_);
    }

    function _set(bytes32 key_, bytes32 value_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).setKey(key_, value_);
    }

    function _setClaimOverrideRecipient(address account_, address recipient_) internal {
        _set(keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_PREFIX, account_)), bytes32(uint256(uint160(recipient_))));
    }

    function _deployComponents() internal {
        _usualMImplementation = address(new UsualM());
        bytes memory usualMData = abi.encodeWithSignature(
            "initialize(address,address)",
            address(_wrappedM),
            _registryAccess
        );
        _usualM = IUsualM(address(new TransparentUpgradeableProxy(_usualMImplementation, _admin, usualMData)));
    }

    function _fundAccounts() internal {
        for (uint256 i = 0; i < _accounts.length; ++i) {
            _giveWrappedM(_accounts[i], 10e6);
            _giveEth(_accounts[i], 0.1 ether);
        }
    }

    function _grantRoles() internal {
        vm.prank(_admin);
        IRegistryAccess(_registryAccess).grantRole(USUAL_M_PAUSE, _admin);
        vm.prank(_admin);
        IRegistryAccess(_registryAccess).grantRole(USUAL_M_UNPAUSE, _admin);

        for (uint256 i = 0; i < _accounts.length; ++i) {
            vm.prank(_admin);
            IRegistryAccess(_registryAccess).grantRole(USUAL_M_UNWRAP, _accounts[i]);
        }

        vm.prank(_admin);
        IRegistryAccess(_registryAccess).grantRole(USUAL_M_MINTCAP_ALLOCATOR, _admin);
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
                        _wrappedM.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                _wrappedM.PERMIT_TYPEHASH(),
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
