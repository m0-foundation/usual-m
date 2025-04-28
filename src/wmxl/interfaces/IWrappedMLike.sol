// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.26;

/**
 * @title  Subset of Wrapped M Token interface required for source contracts.
 * @author M^0 Labs
 */
interface IWrappedMLike {
    /* ============ Interactive Functions ============ */

    /**
     * @notice Allows a calling account to approve `spender` to spend up to `amount` of its token balance.
     * @dev    MUST emit an `Approval` event.
     * @param  spender The address of the account being allowed to spend up to the allowed amount.
     * @param  amount  The amount of the allowance being approved.
     * @return Whether or not the approval was successful.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Approves `spender` to spend up to `amount` of the token balance of `owner`, via a signature.
     * @param  owner    The address of the account who's token balance is being approved to be spent by `spender`.
     * @param  spender  The address of an account allowed to spend on behalf of `owner`.
     * @param  value    The amount of the allowance being approved.
     * @param  deadline The last timestamp where the signature is still valid.
     * @param  v        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s        An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Allows a calling account to transfer `amount` tokens to `recipient`.
     * @param  recipient The address of the recipient who's token balance will be incremented.
     * @param  amount    The amount of tokens being transferred.
     * @return success   Whether or not the transfer was successful.
     */
    function transfer(address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Allows a calling account to transfer `amount` tokens from `sender`, with allowance, to a `recipient`.
     * @param  sender    The address of the sender who's token balance will be decremented.
     * @param  recipient The address of the recipient who's token balance will be incremented.
     * @param  amount    The amount of tokens being transferred.
     * @return success   Whether or not the transfer was successful.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Starts earning for `account` if allowed by the Registrar.
     * @param  account The account to start earning for.
     */
    function startEarningFor(address account) external;

    /**
     * @notice Claims any claimable yield for `account`.
     * @param  account The account under which yield was generated.
     * @return yield   The amount of yield claimed.
     */
    function claimFor(address account) external returns (uint240 yield);

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns the yield accrued for `account`, which is claimable.
     * @param  account The account being queried.
     * @return yield   The amount of yield that is claimable.
     */
    function accruedYieldOf(address account) external view returns (uint240 yield);

    /**
     * @notice Returns the recipient to override as the destination for an account's claim of yield.
     * @param  account   The account being queried.
     * @return recipient The address of the recipient, if any, to override as the destination of claimed yield.
     */
    function claimOverrideRecipientFor(address account) external view returns (address recipient);

    /**
     * @notice Checks if account is an earner.
     * @param  account The account to check.
     * @return earning True if account is an earner, false otherwise.
     */
    function isEarning(address account) external view returns (bool earning);

    /**
     * @notice Returns the token balance of `account`.
     * @param  account The address of some account.
     * @return balance The token balance of `account`.
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /// @notice The current index that would be written to storage if `updateIndex` is called.
    function currentIndex() external view returns (uint128 currentIndex);

    /// @notice Returns the EIP712 domain separator used in the encoding of a signed digest.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the EIP712 typehash used in the encoding of the digest for the permit function.
    function PERMIT_TYPEHASH() external view returns (bytes32);

    /// @notice Returns the number of decimals UIs should assume all amounts have.
    function decimals() external view returns (uint8);

    /// @notice Returns the name of the contract/token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the current total supply of the token.
    function totalSupply() external view returns (uint256);
}
