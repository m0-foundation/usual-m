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

import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IWrappedMLike } from "./interfaces/IWrappedMLike.sol";
import { IRegistryAccess } from "./interfaces/IRegistryAccess.sol";
import { IUsualMV2 } from "./interfaces/IUsualMV2.sol";

import {
    USUAL_M_UNWRAP,
    USUAL_M_PAUSE,
    USUAL_M_UNPAUSE,
    BLACKLIST_ROLE,
    USUAL_M_MINTCAP_ALLOCATOR,
    USUAL_M_YIELD_RECIPIENT_SETTER
} from "./constants.sol";

/**
 * @title  Usual M Extension V2.
 * @author M0 Labs
 * @custom:oz-upgrades-from UsualM
 */
contract UsualMV2 is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUsualMV2 {
    /* ============ Structs, Variables, Modifiers ============ */

    /// @custom:storage-location erc7201:UsualM.storage.v0
    struct UsualMStorageV0 {
        // 1st slot
        uint96 mintCap;
        address wrappedM;
        // 2nd slot
        address registryAccess;
        // 3rd slot
        mapping(address => bool) isBlacklisted;
        // 4th slot
        address mToken;
        // 5th slot
        address yieldRecipient;
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

    /**
     * @custom:oz-upgrades-validate-as-initializer
     * @notice Initializes the UsualMV2 contract.
     * @param  mToken_         The address of the M token.
     * @param  yieldRecipient_ The address of a yield destination.
     * @dev    Initializes the contract and performs the migration from WrappedM to M.
     */
    function initializeV2(address mToken_, address yieldRecipient_) public reinitializer(2) {
        if (mToken_ == address(0)) revert ZeroMToken();

        __ERC20_init("UsualM", "USUALM");
        __ERC20Pausable_init();
        __ERC20Permit_init("UsualM");

        _usualMStorageV0().mToken = mToken_;

        UsualMStorageV0 storage $ = _usualMStorageV0();

        // NOTE: Set the yield recipient that will receive Usual M yield.
        _setYieldRecipient(yieldRecipient_);

        // NOTE: Start earning for Usual M.
        IMTokenLike(mToken_).startEarning();

        // NOTE: Claim for Usual M.
        //       this is the Proxy contract address.
        IWrappedMLike($.wrappedM).claimFor(address(this));

        // NOTE: Then unwrap the whole WrappedM token balance to migrate to M.
        IWrappedMLike($.wrappedM).unwrap(address(this));
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IUsualMV2
    function claimYield() external returns (uint256) {
        uint256 yield_ = yield();

        if (yield_ == 0) return 0;

        emit YieldClaimed(yield_);

        _mint(yieldRecipient(), yield_);

        return yield_;
    }

    /// @inheritdoc IUsualMV2
    function wrap(address recipient, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualMV2
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
        try IMTokenLike(mToken()).permit(msg.sender, address(this), amount, deadline, v, r, s) {} catch {}

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUsualMV2
    function unwrap(address recipient, uint256 amount) external returns (uint256) {
        return _unwrap(msg.sender, recipient, amount);
    }

    /* ============ Special Admin Functions ============ */

    /// @inheritdoc IUsualMV2
    function setMintCap(uint256 newMintCap) external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_MINTCAP_ALLOCATOR, msg.sender)) revert NotAuthorized();

        // Revert if the new mint cap is the same as the current mint cap.
        if (newMintCap == $.mintCap) revert SameValue();

        $.mintCap = _safe96(newMintCap);

        emit MintCapSet(newMintCap);
    }

    /// @inheritdoc IUsualMV2
    function setYieldRecipient(address account) external {
        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess(_usualMStorageV0().registryAccess).hasRole(USUAL_M_YIELD_RECIPIENT_SETTER, msg.sender))
            revert NotAuthorized();

        _setYieldRecipient(account);
    }

    /// @inheritdoc IUsualMV2
    function pause() external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_PAUSE, msg.sender)) revert NotAuthorized();

        _pause();
    }

    /// @inheritdoc IUsualMV2
    function unpause() external {
        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_UNPAUSE, msg.sender)) revert NotAuthorized();

        _unpause();
    }

    /// @inheritdoc IUsualMV2
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

    /// @inheritdoc IUsualMV2
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

    /// @inheritdoc IUsualMV2
    function disableEarning() external virtual {
        IMTokenLike mToken_ = IMTokenLike(_usualMStorageV0().mToken);

        if (!mToken_.isEarning(address(this))) revert EarningIsDisabled();

        mToken_.stopEarning(address(this));
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return DECIMALS_NUMBER;
    }

    /// @inheritdoc IUsualMV2
    function mToken() public view returns (address) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.mToken;
    }

    /// @inheritdoc IUsualMV2
    function registryAccess() public view returns (address) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.registryAccess;
    }

    /// @inheritdoc IUsualMV2
    function mintCap() public view returns (uint256) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.mintCap;
    }

    /// @inheritdoc IUsualMV2
    function isBlacklisted(address account) external view returns (bool) {
        UsualMStorageV0 storage $ = _usualMStorageV0();
        return $.isBlacklisted[account];
    }

    /// @inheritdoc IUsualMV2
    function isEarningEnabled() public view virtual returns (bool) {
        return IMTokenLike(mToken()).isEarning(address(this));
    }

    /// @inheritdoc IUsualMV2
    function getWrappableAmount(uint256 amount) external view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 mintCap_ = mintCap();

        return _min(amount, mintCap_ > totalSupply_ ? mintCap_ - totalSupply_ : 0);
    }

    /// @inheritdoc IUsualMV2
    function yield() public view returns (uint256) {
        unchecked {
            uint256 balance_ = IMTokenLike(mToken()).balanceOf(address(this));
            uint256 totalSupply_ = totalSupply();

            return balance_ > totalSupply_ ? balance_ - totalSupply_ : 0;
        }
    }

    /// @inheritdoc IUsualMV2
    function yieldRecipient() public view returns (address) {
        return _usualMStorageV0().yieldRecipient;
    }
    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Wraps `amount` M from `account` into UsualM for `recipient`.
     * @param  account    The account from which M is deposited.
     * @param  recipient  The account receiving the minted UsualM.
     * @param  amount     The amount of M deposited.
     * @return wrapped    The amount of UsualM minted.
     */
    function _wrap(address account, address recipient, uint256 amount) internal returns (uint256 wrapped) {
        // NOTE: The behavior of `IMTokenLike.transferFrom` is known, so its return can be ignored.
        IMTokenLike(mToken()).transferFrom(account, address(this), amount);

        // NOTE: Mints precise amount of UsualM token to `recipient`.
        //       Option 1: $M transfer from an $M earner to another $M earner (UsualM in earning state): rounds up → rounds up,
        //                 0, 1, or XX extra wei may be locked in UsualM compared to the minted amount of UsualM token.
        //       Option 2: $M transfer from an $M non-earner to an $M earner (UsualM in earning state): precise $M transfer → rounds down,
        //                 0, -1, or -XX wei may be locked in UsualM compared to the minted amount of UsualM token.
        _mint(recipient, wrapped = amount);
    }

    /**
     * @dev    Unwraps `amount` UsualM from `account` into M for `recipient`.
     * @param  account   The account from which UsualM is burned.
     * @param  recipient The account receiving the withdrawn M.
     * @param  amount    The amount of UsualM burned.
     * @return unwrapped The amount of WrappedM tokens withdrawn.
     */
    function _unwrap(address account, address recipient, uint256 amount) internal returns (uint256 unwrapped) {
        if (amount == 0) revert InvalidAmount();

        UsualMStorageV0 storage $ = _usualMStorageV0();

        // Check that caller has a valid access role before proceeding.
        if (!IRegistryAccess($.registryAccess).hasRole(USUAL_M_UNWRAP, msg.sender)) revert NotAuthorized();

        // NOTE: Burn precise `amount` of UsualM token from `account`.
        _burn(account, amount);

        // NOTE: The behavior of `IMTokenLike.transfer` is known, so its return can be ignored.
        // NOTE: Transfer amount of $M to `recipient` and decrease $M balance of the UsualM contract accordingly.
        //       Option 1: $M transfer from an $M earner (UsualM in earning state) to another $M earner: rounds up → rounds up.
        //       Option 2: $M transfer from an $M earner (UsualM in earning state) to an $M non-earner: rounds up → precise $M transfer.
        //       In both cases, 0, 1, or XX extra wei may be deducted from the UsualM contract's $M balance compared to the burned amount of UsualM token.
        IMTokenLike($.mToken).transfer(recipient, unwrapped = amount);
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

    /**
     * @dev Sets the yield recipient.
     * @param account The address of the new yield recipient.
     */
    function _setYieldRecipient(address account) internal {
        if (account == address(0)) revert ZeroYieldRecipient();

        UsualMStorageV0 storage $ = _usualMStorageV0();

        if (account == $.yieldRecipient) return;

        $.yieldRecipient = account;

        emit YieldRecipientSet(account);
    }

    /* ============ Internal View Functions ============ */

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
