// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {
    IERC20Metadata
} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title  Usual SmartM Extension.
 * @author M^0 Labs
 */
interface IUsualM is IERC20Metadata {
    /* ============ Events ============ */

    /// @notice Emitted when address is added to blacklist.
    event Blacklist(address indexed account);

    /// @notice Emitted when address is removed from blacklist.
    event UnBlacklist(address indexed account);

    /// @notice Emitted when token transfers/wraps are attempted by blacklisted account.
    error Blacklisted();

    /// @notice Emitted when action is performed by unauthorized account.
    error NotAuthorized();

    /// @notice Emitted when blacklist/unBlacklist action is performed on the account that is already in desired state.
    error SameValue();

    /// @notice Emitted if account is 0x0.
    error ZeroAddress();

    /// @notice Emitted if SmartM Token is 0x0.
    error ZeroSmartM();

    /// @notice Emitted if Registry Access is 0x0.
    error ZeroRegistryAccess();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Wraps `amount` SmartM from the caller into UsualM for `recipient`.
     * @param  recipient The account receiving the minted UsualM.
     * @param  amount    The amount of SmartM deposited.
     * @return           The amount of UsualM minted.
     */
    function wrap(address recipient, uint256 amount) external returns (uint256);

    /**
     * @notice Wraps all the SmartM from the caller into UsualM for `recipient`.
     * @param  recipient The account receiving the minted UsualM.
     * @return           The amount of UsualM minted.
     */
    function wrap(address recipient) external returns (uint256);

    /**
     * @notice Wraps `amount` SmartM from the caller into UsualM for `recipient`, using a permit.
     * @param  recipient The account receiving the minted UsualM.
     * @param  amount    The amount of SmartM deposited.
     * @param  deadline  The last timestamp where the signature is still valid.
     * @param  v         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @return           The amount of UsualM minted.
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
     * @notice Unwraps `amount` UsualM from the caller into SmartM for `recipient`.
     * @param  recipient The account receiving the withdrawn SmartM.
     * @param  amount    The amount of UsualM burned.
     * @return           The amount of SmartM withdrawn.
     */
    function unwrap(address recipient, uint256 amount) external returns (uint256);

    /**
     * @notice Unwraps all the UsualM from the caller into SmartM for `recipient`.
     * @param  recipient The account receiving the withdrawn SmartM.
     * @return           The amount of SmartM withdrawn.
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

    /// @notice Returns wheather account is blacklisted.
    function isBlacklisted(address account) external view returns (bool);

    /// @notice Returns the SmartM Token address.
    function smartM() external view returns (address);

    /// @notice Returns the Registry Access address.
    function registryAccess() external view returns (address);
}
