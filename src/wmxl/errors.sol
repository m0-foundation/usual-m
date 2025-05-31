// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

error AlreadyClaimed();
error AlreadyWhitelisted();
error AmountTooBig();
error AmountTooLow();
error AmountIsZero();
error Blacklisted();

error NotAllowlisted(address);

error Empty();
error SameValue();

error Invalid();
error InvalidToken();
error InvalidName();
error InvalidSymbol();

error LockedOffer();

error NotAuthorized();
error NotClaimableYet();
error NotWhitelisted();
error NullAddress();
error NullContract();

error PriceUpdateBlocked();
error OracleNotWorkingNotCurrent();
error OracleNotInitialized();
error OutOfBounds();
error InvalidTimeout();

error RedeemMustNotBePaused();
error RedeemMustBePaused();
error SwapMustNotBePaused();
error SwapMustBePaused();

error StablecoinDepeg();
error DepegThresholdTooHigh();

error TokenNotWhitelist();

error BondFinished();
error BondNotFinished();

error BeginInPast();

error CBRIsTooHigh();
error CBRIsNull();

error RedeemFeeTooBig();
error CancelFeeTooBig();
error MinterRewardTooBig();
error CollateralProviderRewardTooBig();
error DistributionRatioInvalid();
error TooManyRWA();
error FailingTransfer();