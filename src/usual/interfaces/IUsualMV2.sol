// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

import {
    IERC20Metadata
} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title  Usual M Extension V2 interface.
 * @author M0 Labs
 */
interface IUsualMV2 is IERC20Metadata {
    /* ============ Events ============ */

    /// @notice Emitted when address is added to blacklist.
    event Blacklist(address indexed account);

    /// @notice Emitted when address is removed from blacklist.
    event UnBlacklist(address indexed account);

    /// @notice Emitted when mint cap is set.
    event MintCapSet(uint256 newMintCap);

    /**
     * @notice Emitted when this contract's excess M is claimed.
     * @param  yield The amount of M yield claimed.
     */
    event YieldClaimed(uint256 yield);

    /**
     * @notice Emitted when the yield recipient is set.
     * @param  newRecipient The address of the new yield recipient.
     */
    event YieldRecipientSet(address indexed newRecipient);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when token transfers/wraps are attempted by blacklisted account.
    error Blacklisted();

    /// @notice Emitted when action is performed by unauthorized account.
    error NotAuthorized();

    /// @notice Emitted when blacklist/unBlacklist action is performed on the account that is already in desired state.
    error SameValue();

    /// @notice Emitted if account is 0x0.
    error ZeroAddress();

    /// @notice Emitted if WrappedM Token is 0x0.
    error ZeroWrappedM();

    /// @notice Emitted if Registry Access is 0x0.
    error ZeroRegistryAccess();

    /// @notice Emitted if Mint Cap is exceeded.
    error MintCapExceeded();

    /// @notice Emitted if Mint Cap > 2^96 - 1.
    error InvalidUInt96();

    /// @notice Emitted if `wrap` or `unwrap` amount is 0.
    error InvalidAmount();

    /// @notice Emitted when M earning is disabled for UsualM.
    error EarningIsDisabled();

    /// @notice Emitted if no yield is available to claim.
    error NoYield();

    /// @notice Emitted if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted in constructor if Yield Recipient is 0x0.
    error ZeroYieldRecipient();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Wraps `amount` M from the caller into UsualM for `recipient`.
     * @param  recipient The account receiving the minted UsualM.
     * @param  amount    The amount of M deposited.
     */
    function wrap(address recipient, uint256 amount) external;

    /**
     * @notice Wraps `amount` M from the caller into UsualM for `recipient`, using a permit.
     * @param  recipient The account receiving the minted UsualM.
     * @param  amount    The amount of M deposited.
     * @param  deadline  The last timestamp where the signature is still valid.
     * @param  v         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Unwraps `amount` UsualM from the caller into M for `recipient`.
     * @param  recipient The account receiving the withdrawn M.
     * @param  amount    The amount of UsualM burned.
     */
    function unwrap(address recipient, uint256 amount) external;

    /// @notice Claims accrued yield to yield recipient.
    function claimYield() external returns (uint256);

    /* ============ Special Admin Functions ============ */

    /**
     * @notice Adds an address to the blacklist.
     * @dev Can only be called by the `BLACKLIST_ROLE`.
     * @param account The address to be blacklisted.
     */
    function blacklist(address account) external;

    /**
     * @notice Removes an address from the blacklist.
     * @dev Can only be called by the `BLACKLIST_ROLE`.
     * @param account The address to be removed from the blacklist.
     */
    function unBlacklist(address account) external;

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the `USUAL_M_PAUSE` role.
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the `USUAL_M_UNPAUSE` role.
    function unpause() external;

    /**
     * @notice Sets the mint cap.
     * @param newMintCap The new mint cap, should be different from the current value.
     * @dev The new mint cap should be less than or equal to 2^96 - 1.
     * @dev Can only be called by the `USUAL_M_MINTCAP_ALLOCATOR` role.
     * @dev number of deciamls is 6 for the mint cap value.
     **/
    function setMintCap(uint256 newMintCap) external;

    /**
     * @notice Disables earning of UsualM if disallowed by the TTG Registrar.
     * @dev    Callable by anyone.
     * @dev    Can only be called once and earning can not be re-enabled afterward.
     */
    function disableEarning() external;

    /**
     * @notice Sets the yield recipient.
     * @dev    Only callable by the USUAL_M_YIELD_RECIPIENT_SETTER role.
     * @dev    Reverts if account is 0x0.
     * @dev    Rreturns early if the account is already the yield recipient.
     * @param  account The address of the new yield recipient.
     */
    function setYieldRecipient(address account) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns whether the account is blacklisted.
    function isBlacklisted(address account) external view returns (bool);

    /// @notice Returns the Registry Access address.
    function registryAccess() external view returns (address);

    /// @notice Returns the Mint Cap amount.
    function mintCap() external view returns (uint256);

    /// @notice Returns the available wrappable amount for the current values of `mintCap` and `totalSupply`.
    function getWrappableAmount(uint256 amount) external view returns (uint256);

    /// @notice Whether UsualM is earning M.
    function isEarningEnabled() external view returns (bool);

    /// @notice Returns the M token address.
    function mToken() external view returns (address);

    /// @notice The amount of accrued yield.
    function yield() external view returns (uint256);

    /// @notice The address of the yield recipient.
    function yieldRecipient() external view returns (address);
}
