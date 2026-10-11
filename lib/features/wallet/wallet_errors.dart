import '../../core/api/api_client.dart';
import '../../core/l10n/gen/app_localizations.dart';

/// Localized copy for a failed wallet call. Only the error CODE is read: the server's English `message` is never
/// shown, so every language gets its own text and an unknown code degrades to the generic line.
String walletErrorCopy(AppLocalizations l10n, Object error) =>
    error is ApiException ? walletErrorCodeCopy(l10n, error.code, error.fields) : l10n.walletErrGeneric;

/// The same mapping from a bare code (what [WriteState.errorCode] / [WriteState.fieldErrors] carry).
String walletErrorCodeCopy(AppLocalizations l10n, String code, [Map<String, String> fields = const {}]) {
  return switch (code) {
    'network' => l10n.walletErrNetwork,
    'unauthorized' => l10n.walletErrSession,
    'idempotency_in_progress' => l10n.walletErrInProgress,
    'rate_limited' => l10n.walletErrRateLimited(fields['retryAfterSeconds'] ?? '60'),
    'account_pending_deletion' => l10n.walletErrPendingDeletion,
    'email_required' => l10n.walletErrEmailRequired,
    'payment_unavailable' || 'deposit_failed' => l10n.walletErrPaymentUnavailable,
    'account_unresolvable' => l10n.walletErrAccountUnresolvable,
    'unknown_bank' => l10n.walletErrUnknownBank,
    'already_verified' => l10n.walletErrAlreadyVerified,
    'payout_unavailable' => l10n.walletErrPayoutUnavailable,
    'kyc_required' => l10n.walletErrKycRequired,
    'insufficient_balance' => l10n.walletErrInsufficient,
    'withdrawal_pending' => l10n.walletErrWithdrawalPending,
    _ => l10n.walletErrGeneric,
  };
}
