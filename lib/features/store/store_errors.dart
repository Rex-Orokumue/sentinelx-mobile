import '../../core/api/api_client.dart';
import '../../core/l10n/gen/app_localizations.dart';

/// Localized copy for a failed store call. Only the error CODE is read: the server's English `message` is never
/// shown, so every language gets its own text and an unknown code degrades to the generic line.
String storeErrorCopy(AppLocalizations l10n, Object error) =>
    error is ApiException ? storeErrorCodeCopy(l10n, error.code) : l10n.storeErrGeneric;

/// The same mapping from a bare code (what a `WriteState.errorCode` carries).
String storeErrorCodeCopy(AppLocalizations l10n, String code) => switch (code) {
      'network' => l10n.storeErrNetwork,
      'unauthorized' => l10n.storeErrSession,
      'idempotency_in_progress' => l10n.storeErrInProgress,
      'not_found' => l10n.storeErrNotFound,
      'item_unavailable' => l10n.storeErrUnavailable,
      'already_owned' => l10n.storeErrOwned,
      'insufficient_coins' => l10n.storeErrInsufficient,
      'not_owned' => l10n.storeErrNotOwned,
      'store_unavailable' || 'store_load_failed' => l10n.storeErrStore,
      'account_pending_deletion' => l10n.storeErrPendingDeletion,
      _ => l10n.storeErrGeneric,
    };
