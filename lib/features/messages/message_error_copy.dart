import '../../core/api/api_client.dart';
import '../../core/l10n/gen/app_localizations.dart';

/// Maps DM API error codes to localized copy. Server `error.message` is English and never shown. Branches on
/// `ApiException.code`, never on `status`: the pinned contract omits 404/409 for these operations (Ruling 7),
/// so statuses are not reliable. Unknown codes, network failures and non-API errors fall back to generic copy.
String dmErrorCopy(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.dmErrorGeneric;
  return switch (error.code) {
    'not_found' => l10n.dmErrorNotFound,
    'validation' => l10n.dmErrorValidation,
    'blocked_by_me' => l10n.dmErrorBlockedByMe,
    'blocked' => l10n.dmErrorBlocked,
    'messaging_restricted' => l10n.dmErrorRestricted,
    'edit_window_closed' => l10n.dmErrorEditWindow,
    'not_forwardable' => l10n.dmErrorNotForwardable,
    'request_pending_limit' => l10n.dmErrorRequestLimit,
    'request_media_not_allowed' => l10n.dmErrorRequestNoMedia,
    'send_failed' => l10n.dmErrorSendFailed,
    'action_failed' => l10n.dmErrorAction,
    _ => l10n.dmErrorGeneric,
  };
}
