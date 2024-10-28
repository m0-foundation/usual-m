// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {
    ERC20PausableUpgradeable
} from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { ERC20Upgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { IERC20Metadata } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IUCToken } from "./interfaces/IUCToken.sol";
import { IRegistryAccess } from "./interfaces/IRegistryAccess.sol";

import { DEFAULT_ADMIN_ROLE, UCT_UNWRAP, UCT_PAUSE_UNPAUSE } from "./constants.sol";

/**
 * @title  ERC20 Token contract for M UC extension.
 * @author M^0 Labs
 */
contract UCToken is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUCToken {
    using SafeERC20 for ERC20;

    /* ============ Variables ============ */

    /// @custom:storage-location erc7201:UCToken.storage.v0
    struct UCTStorageV0 {
        address mToken;
        address registryAccess;
        address treasury;
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address mToken_, address registryAccess_, address treasury_) public initializer {
        if (mToken_ == address(0)) revert ZeroMToken();
        if (registryAccess_ == address(0)) revert ZeroRegistryAccess();
        if (treasury_ == address(0)) revert ZeroTreasury();

        __ERC20_init("UCToken", "UCT");
        __ERC20Pausable_init();
        __ERC20Permit_init("UCToken");

        UCTStorageV0 storage $ = _uctStorageV0();
        $.mToken = mToken_;
        $.registryAccess = registryAccess_;
        $.treasury = treasury_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IUCToken
    function wrap(address recipient, uint256 amount) external returns (uint256) {
        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function wrap(address recipient) external returns (uint256) {
        return _wrap(msg.sender, recipient, IMTokenLike(mToken()).balanceOf(msg.sender));
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
        IMTokenLike(mToken()).permit(msg.sender, address(this), amount, deadline, v, r, s);

        return _wrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function unwrap(address recipient, uint256 amount) external onlyMatchingRole(UCT_UNWRAP) returns (uint256) {
        return _unwrap(msg.sender, recipient, amount);
    }

    /// @inheritdoc IUCToken
    function unwrap(address recipient) external onlyMatchingRole(UCT_UNWRAP) returns (uint256) {
        return _unwrap(msg.sender, recipient, balanceOf(msg.sender));
    }

    /// @inheritdoc IUCToken
    function pause() external onlyMatchingRole(UCT_PAUSE_UNPAUSE) {
        _pause();
    }

    /// @inheritdoc IUCToken
    function unpause() external onlyMatchingRole(UCT_PAUSE_UNPAUSE) {
        _unpause();
    }

    /// @inheritdoc IUCToken
    function blacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        // Allow only the admin to blacklist an address.
        // Note: avoid reading storage twice by using `onlyMatchingRole` modifier
        UCTStorageV0 storage $ = _uctStorageV0();
        if (!IRegistryAccess($.registryAccess).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert NotAuthorized();

        // Idempotent operation: if the account is already blacklisted, do nothing.
        if ($.isBlacklisted[account]) return;

        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @inheritdoc IUCToken
    function unBlacklist(address account) external {
        if (account == address(0)) revert ZeroAddress();

        // Allow only the admin to blacklist an address.
        // Note: avoid reading storage twice by using `onlyMatchingRole` modifier
        UCTStorageV0 storage $ = _uctStorageV0();
        if (!IRegistryAccess($.registryAccess).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert NotAuthorized();

        // Idempotent operation: if the account is not blacklisted, do nothing.
        if (!$.isBlacklisted[account]) return;

        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return 6;
    }

    /// @inheritdoc IUCToken
    function mToken() public view returns (address) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.mToken;
    }

    /// @inheritdoc IUCToken
    function registryAccess() public view returns (address) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.registryAccess;
    }

    /// @inheritdoc IUCToken
    function treasury() public view returns (address) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.treasury;
    }

    /// @inheritdoc IUCToken
    function isBlacklisted(address account) external view returns (bool) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return $.isBlacklisted[account];
    }

    /// @inheritdoc IUCToken
    function totalAccruedYield() public view returns (uint256) {
        uint256 mTokenBalanceOf = _getTreasuryBalance();
        uint256 uctTotalSupply = totalSupply();
        unchecked {
            return mTokenBalanceOf > uctTotalSupply ? mTokenBalanceOf - uctTotalSupply : 0;
        }
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Wraps `amount` M from `account` into wM for `recipient`.
     * @param  account   The account from which M is deposited.
     * @param  recipient The account receiving the minted wM.
     * @param  amount    The amount of M deposited.
     * @return wrapped   The amount of wM minted.
     */
    function _wrap(address account, address recipient, uint256 amount) internal returns (uint256 wrapped) {
        uint256 startingBalance = _getTreasuryBalance();

        // NOTE: The behavior of `IMTokenLike.transferFrom` is known, so its return can be ignored.
        IMTokenLike(mToken()).transferFrom(account, treasury(), amount);

        // NOTE: When this WrappedMToken contract is earning, any amount of M sent to it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount less than `amount`. In order to capture the real increase in M, the difference between the
        //       starting and ending M balance is minted as WrappedM.
        _mint(recipient, wrapped = _getTreasuryBalance() - startingBalance);
    }

    /**
     * @dev    Unwraps `amount` wM from `account` into M for `recipient`.
     * @param  account   The account from which WM is burned.
     * @param  recipient The account receiving the withdrawn M.
     * @param  amount    The amount of wM burned.
     * @return unwrapped The amount of M withdrawn.
     */
    function _unwrap(address account, address recipient, uint256 amount) internal returns (uint256) {
        _burn(account, amount);

        (address mToken_, address treasury_, uint256 startingBalance) = _getTreasuryInfo();

        // NOTE: The behavior of `IMTokenLike.transfer` is known, so its return can be ignored.
        IMTokenLike(mToken_).transferFrom(treasury_, recipient, amount);

        // NOTE: When this WrappedMToken contract is earning, any amount of M sent from it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount more than `amount`. In order to capture the real decrease in M, the difference between the
        //       ending and starting M balance is returned.
        return startingBalance - _getTreasuryBalance();
    }

    /// @notice Hook that ensures token transfers are not made from or to not blacklisted addresses.
    /// @param from The address sending the tokens.
    /// @param to The address receiving the tokens.
    /// @param amount The amount of tokens being transferred.
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        UCTStorageV0 storage $ = _uctStorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) revert Blacklisted();

        super._update(from, to, amount);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @notice Returns the balance of M held in the treasury.
    function _getTreasuryBalance() internal view returns (uint256) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return IMTokenLike($.mToken).balanceOf($.treasury);
    }

    function _getTreasuryInfo() internal view returns (address, address, uint256) {
        UCTStorageV0 storage $ = _uctStorageV0();
        return ($.mToken, $.treasury, IMTokenLike($.mToken).balanceOf($.treasury));
    }
}
