// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

import {
    ERC20PausableUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { IERC20Metadata } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IWrappedMLike } from "./interfaces/IWrappedMLike.sol";
import { IUsualM } from "./interfaces/IUsualM.sol";
import { IRegistryAccess } from "./interfaces/IRegistryAccess.sol";

import {
    USUAL_M_UNWRAP,
    USUAL_M_PAUSE,
    USUAL_M_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_M_MINTCAP_ALLOCATOR
} from "./constants.sol";

/**
 * @title  Usual Wrapped M Extension.
 * @author M^0 Labs
 */
contract UsualM is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUsualM {
    /* ============ Structs, Variables, Modifiers ============ */

    /// @custom:storage-location erc7201:UsualM.storage.v0
    struct UsualMStorageV0 {
        // 1st slot
        uint96 mintCap;
        address wrappedM;
        // 2nd slot
        address registryAccess;
        // next slots
        mapping(address => bool) isBlacklisted;
    }

    // keccak256(abi.encode(uint256(keccak256("UsualM.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant UsualMStorageV0Location =
        0xaf0b0773f61ce9af1982ff9a13506e1d8ad90f04391405f722e2ad38e8ffd300;

    /// @notice The number of decimals for the UsualM token.
    uint8 public constant DECIMALS_NUMBER = 6;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _usualMStorageV0() internal pure returns (UsualMStorageV0 storage $) {
        bytes32 position = UsualMStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /* ============ Constructor ============ */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* ============ Initializer ============ */

    function initialize(address wrappedM_, address registryAccess_) public initializer {
        if (wrappedM_ == address(0)) revert ZeroWrappedM();
        if (registryAccess_ == address(0)) revert ZeroRegistryAccess();

        __ERC20_init("UsualM", "USUALM");
        __ERC20Pausable_init();
        __ERC20Permit_init("UsualM");

        UsualMStorageV0 storage $ = _usualMStorageV0();
        $.wrappedM = wrappedM_;
        $.registryAccess = registryAccess_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IUsualM
    function wrap(address recipient, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualM
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        // NOTE: `permit` call failures can be safely ignored to remove the risk of transactions being reverted due to front-run.
        try IWrappedMLike(wrappedM()).permit(msg.sender, address(this), amount, deadline, v, r, s) {} catch {}

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualM
    function unwrap(address recipient, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_UNWRAP, msg.sender)) revert NotAuthorized();

        return _unwrap(msg.sender, recipient, amount);
    }

    /* ============ Special Admin Functions ============ */

    /// @inheritdoc IUsualM
    function setMintCap(uint256 newMintCap) external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_MINTCAP_ALLOCATOR, msg.sender)) revert NotAuthorized();

        // Revert if the new mint cap is the same as the current mint cap.
        if (newMintCap == $.mintCap) revert SameValue();

        $.mintCap = _safe96(newMintCap);

        emit MintCapSet(newMintCap);
    }

    /// @inheritdoc IUsualM
    function pause() external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_PAUSE, msg.sender)) revert NotAuthorized();

        _pause();
    }

    /// @inheritdoc IUsualM
    function unpause() external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_UNPAUSE, msg.sender)) revert NotAuthorized();

        _unpause();
    }

    /// @inheritdoc IUsualM
    /// @dev Can only be called by an account with the `BLACKLIST_ROLE` role.
    function blacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(BLACKLIST_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if `account` is already blacklisted.
        if ($.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @inheritdoc IUsualM
    /// @dev Can only be called by an account with the `BLACKLIST_ROLE` role.
    function unBlacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(BLACKLIST_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if `account` is not blacklisted.
        if (!$.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return DECIMALS_NUMBER;
    }

    /// @inheritdoc IUsualM
    function wrappedM() public view returns (address) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.wrappedM;
    }

    /// @inheritdoc IUsualM
    function registryAccess() public view returns (address) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.registryAccess;
    }

    /// @inheritdoc IUsualM
    function mintCap() public view returns (uint256) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.mintCap;
    }

    /// @inheritdoc IUsualM
    function isBlacklisted(address account) external view returns (bool) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.isBlacklisted[account];
    }

    /// @inheritdoc IUsualM
    function getWrappableAmount(uint256 amount) external view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 mintCap_ = mintCap();

        return _min(amount, mintCap_ > totalSupply_ ? mintCap_ - totalSupply_ : 0);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Wraps `amount` WrappedM from `account` into UsualM for `recipient`.
     * @param  account    The account from which WrappedM is deposited.
     * @param  recipient  The account receiving the minted UsualM.
     * @param  amount     The amount of WrappedM deposited.
     * @return wrapped    The amount of UsualM minted.
     */
    function _wrap(address account, address recipient, uint256 amount) internal returns (uint256 wrapped) {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // NOTE: The behavior of `IWrappedMLike.transferFrom` is known, so its return can be ignored.
        IWrappedMLike($.wrappedM).transferFrom(account, address(this), amount);

        _mint(recipient, wrapped = amount);
    }

    /**
     * @dev    Unwraps `amount` UsualM from `account` into WrappedM for `recipient`.
     * @param  account   The account from which UsualM is burned.
     * @param  recipient The account receiving the withdrawn WrappedM.
     * @param  amount    The amount of UsualM burned.
     * @return unwrapped The amount of WrappedM tokens withdrawn.
     */
    function _unwrap(address account, address recipient, uint256 amount) internal returns (uint256 unwrapped) {
        _burn(account, amount);

        // NOTE: The behavior of `IWrappedMLike.transfer` is known, so its return can be ignored.
        IWrappedMLike(wrappedM()).transfer(recipient, unwrapped = amount);
    }

    /**
     * @dev    Hook that ensures token transfers are not made from or to blacklisted addresses.
     * @param  from   The address sending the tokens.
     * @param  to     The address receiving the tokens.
     * @param  amount The amount of tokens being transferred.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) revert Blacklisted();

        // Check if minting would exceed the mint cap
        if (from == address(0) && totalSupply() + amount > $.mintCap) revert MintCapExceeded();

        ERC20PausableUpgradeable._update(from, to, amount);
    }

    /// @dev Compares two uint256 values and returns the lesser one.
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @dev Converts a uint256 to a uint96, reverting if the conversion without loss is not possible.
    function _safe96(uint256 n) internal pure returns (uint96) {
        if (n > type(uint96).max) revert InvalidUInt96();
        return uint96(n);
    }
}
