import '../../../core/l10n/gen/app_localizations.dart';

/// Server error codes become localized copy here; the server's English `message` is never shown. Codes
/// shared by every Settings call (rate limit, no network, unknown) fall through to [genericAccountErrorCopy].
String genericAccountErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'reauth_rate_limited' => l10n.mobileSettingsReauthRateLimited,
      'network' => l10n.mobileSettingsNetworkError,
      _ => l10n.mobileSettingsGenericError,
    };

String emailChangeErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'wrong_password' => l10n.emailChangeErrorsWrongPassword,
      'google_only' => l10n.emailChangeErrorsGoogleOnly,
      'same_email' => l10n.emailChangeErrorsSameEmail,
      'email_banned' => l10n.emailChangeErrorsEmailBanned,
      'email_in_use' => l10n.emailChangeErrorsEmailInUse,
      'failed' => l10n.emailChangeErrorsFailed,
      'validation_failed' => l10n.emailChangeErrorsInvalidEmail,
      _ => genericAccountErrorCopy(l10n, code),
    };

String unlinkErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'wrong_password' => l10n.signInMethodsErrorsWrongPassword,
      'last_identity' => l10n.signInMethodsErrorsLastIdentity,
      'not_linked' => l10n.signInMethodsErrorsNotLinked,
      'linking_unavailable' => l10n.mobileSettingsLinkingUnavailable,
      'failed' => l10n.signInMethodsErrorsFailed,
      _ => genericAccountErrorCopy(l10n, code),
    };

String phoneErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'phone_invalid' => l10n.mobileSettingsPhoneErrorInvalid,
      'phone_cooldown' => l10n.mobileSettingsPhoneErrorCooldown,
      'phone_daily_limit' => l10n.mobileSettingsPhoneErrorDailyLimit,
      'phone_send_failed' => l10n.mobileSettingsPhoneErrorSendFailed,
      'phone_unavailable' => l10n.mobileSettingsPhoneUnavailable,
      'phone_code_invalid' => l10n.mobileSettingsPhoneErrorCodeInvalid,
      'phone_code_missing' => l10n.mobileSettingsPhoneErrorCodeMissing,
      'phone_code_expired' => l10n.mobileSettingsPhoneErrorCodeExpired,
      'phone_code_wrong' => l10n.mobileSettingsPhoneErrorCodeWrong,
      'phone_attempts_exceeded' => l10n.mobileSettingsPhoneErrorAttempts,
      _ => genericAccountErrorCopy(l10n, code),
    };
