// SPDX-License-Identifier: BUSL-1.1

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
import { SafeERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { IERC20Metadata } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ISmartMTokenLike } from "./interfaces/ISmartMTokenLike.sol";
import { IUCToken } from "./interfaces/IUCToken.sol";
import { IRegistryAccess } from "./interfaces/IRegistryAccess.sol";

import { DEFAULT_ADMIN_ROLE, UCT_UNWRAP, UCT_PAUSE_UNPAUSE } from "./constants.sol";

/**
 * @title  ERC20 Token contract for Usual SmartM extension.
 * @author M^0 Labs
 */
contract UCToken is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUCToken {
    using SafeERC20 for ERC20;

    /* ============ Structs, Variables, Modifiers ============ */

    /// @custom:storage-location erc7201:UCToken.storage.v0
    struct UCTStorageV0 {
        address smartMToken;
        address registryAccess;
        mapping(address => bool) isBlacklisted;
    }

    // keccak256(abi.encode(uint256(keccak256("UCToken.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant UCTStorageV0Location = 0x0ccee811a51b7a9ad96750cc270a934f534adda6dde5843cc4def33bcc12a300;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _uctStorageV0() internal pure returns (UCTStorageV0 storage $) {
        bytes32 position = UCTStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    modifier onlyMatchingRole(bytes32 role) {
        UCTStorageV0 storage $ = _uctStorageV0();
        if (!IRegistryAccess($.registryAccess).hasRole(role, msg.sender)) revert NotAuthorized();

        _;
    }

    /* ============ Constructor ============ */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* ============ Initializer ============ */

    function initialize(address smartMToken_, address registryAccess_) public initializer {
        if (smartMToken_ == address(0)) revert ZeroSmartMToken();
        if (registryAccess_ == address(0)) revert ZeroRegistryAccess();

        __ERC20_init("UCToken", "UCT");
        __ERC20Pausable_init();
        __ERC20Permit_init("UCToken");

        UCTStorageV0 storage $ = _uctStorageV0();
        $.smartMToken = smartMToken_;
        $.registryAccess = registryAccess_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IUCToken
    function wrap(address recipient, uint256 amount) external returns (uint256) {
        return _wrap(smartMToken(), msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function wrap(address recipient) external returns (uint256) {
        address smartMToken_ = smartMToken();
        return _wrap(smartMToken_, msg.sender, recipient, ISmartMTokenLike(smartMToken_).balanceOf(msg.sender));
    }

    /// @inheritdoc IUCToken
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        address smartMToken_ = smartMToken();

        ISmartMTokenLike(smartMToken_).permit(msg.sender, address(this), amount, deadline, v, r, s);

        return _wrap(smartMToken_, msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function unwrap(address recipient, uint256 amount) external onlyMatchingRole(UCT_UNWRAP) returns (uint256) {
        return _unwrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function unwrap(address recipient) external onlyMatchingRole(UCT_UNWRAP) returns (uint256) {
        return _unwrap(msg.sender, recipient, balanceOf(msg.sender));
    }

    /* ============ Special Admin Functions ============ */

    /// @inheritdoc IUCToken
    function pause() external onlyMatchingRole(UCT_PAUSE_UNPAUSE) {
        _pause();
    }

    /// @inheritdoc IUCToken
    function unpause() external onlyMatchingRole(UCT_PAUSE_UNPAUSE) {
        _unpause();
    }

    /// @inheritdoc IUCToken
    /// @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE` role.
    function blacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        // NOTE: Avoid reading storage twice while using `onlyMatchingRole` modifier.
        UCTStorageV0 storage $ = _uctStorageV0();
        if (!IRegistryAccess($.registryAccess).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if the account is already blacklisted.
        if ($.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @inheritdoc IUCToken
    /// @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE` role.
    function unBlacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        // NOTE: Avoid reading storage twice while using `onlyMatchingRole` modifier.
        UCTStorageV0 storage $ = _uctStorageV0();
        if (!IRegistryAccess($.registryAccess).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert NotAuthorized();

        // Revert in the same way as USD0 if the account is not blacklisted.
        if (!$.isBlacklisted[account]) revert SameValue();

        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return 6;
    }

    /// @inheritdoc IUCToken
    function smartMToken() public view returns (address) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.smartMToken;
    }

    /// @inheritdoc IUCToken
    function registryAccess() public view returns (address) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.registryAccess;
    }

    /// @inheritdoc IUCToken
    function isBlacklisted(address account) external view returns (bool) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.isBlacklisted[account];
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Wraps `amount` M from `account` into UCToken for `recipient`.
     * @param  smartMToken_ The address of the SmartM token.
     * @param  account      The account from which M is deposited.
     * @param  recipient    The account receiving the minted UCToken.
     * @param  amount       The amount of SmartM deposited.
     * @return wrapped      The amount of UCToken minted.
     */
    function _wrap(
        address smartMToken_,
        address account,
        address recipient,
        uint256 amount
    ) internal returns (uint256 wrapped) {
        // NOTE: The behavior of `ISmartMTokenLike.transferFrom` is known, so its return can be ignored.
        ISmartMTokenLike(smartMToken_).transferFrom(account, address(this), amount);

        _mint(recipient, wrapped = amount);
    }

    /**
     * @dev    Unwraps `amount` UCToken from `account` into SmartM for `recipient`.
     * @param  account   The account from which UCToken is burned.
     * @param  recipient The account receiving the withdrawn SmartM.
     * @param  amount    The amount of UCToken burned.
     * @return unwrapped The amount of SmartM tokens withdrawn.
     */
    function _unwrap(address account, address recipient, uint256 amount) internal returns (uint256 unwrapped) {
        _burn(account, amount);

        // NOTE: The behavior of `ISmartMTokenLike.transfer` is known, so its return can be ignored.
        ISmartMTokenLike(smartMToken()).transfer(recipient, unwrapped = amount);
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
        UCTStorageV0 storage $ = _uctStorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) revert Blacklisted();

        super._update(from, to, amount);
    }
}
