// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IERC20Metadata } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title  UCT Extension.
 * @author M^0 Labs
 */
interface IUCToken is IERC20Metadata {
    /* ============ Events ============ */

    /// @notice Emitted when address is added to blacklist.
    event Blacklist(address indexed account);

    /// @notice Emitted when address is removed from blacklist.
    event UnBlacklist(address indexed account);

    /// @notice Emitted when token transfers are attempted by blacklisted account.
    error Blacklisted();

    /// @notice Emitted when action is performed by unauthorized account.
    error NotAuthorized();

    /// @notice Emitted if account is 0x0.
    error ZeroAddress();

    /// @notice Emitted if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted if Registry Access is 0x0.
    error ZeroRegistryAccess();

    /// @notice Emitted if Treasury is 0x0.
    error ZeroTreasury();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Wraps `amount` M from the caller into UCT for `recipient`.
     * @param  recipient The account receiving the minted UCT.
     * @param  amount    The amount of M deposited.
     * @return           The amount of UCT minted.
     */
    function wrap(address recipient, uint256 amount) external returns (uint256);

    /**
     * @notice Wraps all the M from the caller into UCT for `recipient`.
     * @param  recipient The account receiving the minted UCT.
     * @return           The amount of UCT minted.
     */
    function wrap(address recipient) external returns (uint256);

    /**
     * @notice Wraps `amount` M from the caller into UCT for `recipient`, using a permit.
     * @param  recipient The account receiving the minted UCT.
     * @param  amount    The amount of M deposited.
     * @param  deadline  The last timestamp where the signature is still valid.
     * @param  v         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @return wrapped   The amount of UCT minted.
     */
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Unwraps `amount` UCT from the caller into M for `recipient`.
     * @param  recipient The account receiving the withdrawn M.
     * @param  amount    The amount of UCT burned.
     * @return           The amount of M withdrawn.
     */
    function unwrap(address recipient, uint256 amount) external returns (uint256);

    /**
     * @notice Unwraps all the UCT from the caller into M for `recipient`.
     * @param  recipient The account receiving the withdrawn M.
     * @return           The amount of M withdrawn.
     */
    function unwrap(address recipient) external returns (uint256);

    /**
     * @notice Adds an address to the blacklist.
     * @dev Can only be called by the admin.
     * @param account The address to be blacklisted.
     */
    function blacklist(address account) external;

    /**
     * @notice Removes an address from the blacklist.
     * @dev Can only be called by the admin.
     * @param account The address to be removed from the blacklist.
     */
    function unBlacklist(address account) external;

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the admin.
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the admin.
    function unpause() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The accrued yield of M locked in the M extension.
    function totalAccruedYield() external view returns (uint256);

    /// @notice Returns wheather account is blacklisted.
    function isBlacklisted(address account) external view returns (bool);

    /// @notice Returns the M Token address.
    function mToken() external view returns (address);

    /// @notice Returns the Registry Access address.
    function registryAccess() external view returns (address);

    /// @notice Returns the Treasury address.
    function treasury() external view returns (address);
}
