import '../../core/l10n/gen/app_localizations.dart';

/// Maps notification API error codes to localized copy. Server `error.message` is English and never
/// shown; unknown codes fall back to the generic message.
String notificationErrorCopy(AppLocalizations l10n, String code) {
  return switch (code) {
    'validation_failed' => l10n.ntfErrValidation,
    'not_found' => l10n.ntfErrNotFound,
    'network' => l10n.ntfErrNetwork,
    _ => l10n.ntfErrGeneric,
  };
}
