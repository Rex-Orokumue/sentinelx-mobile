import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/account/settings/account_error_copy.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('email change codes map to the shared web copy', () {
    expect(emailChangeErrorCopy(l10n, 'wrong_password'), l10n.emailChangeErrorsWrongPassword);
    expect(emailChangeErrorCopy(l10n, 'google_only'), l10n.emailChangeErrorsGoogleOnly);
    expect(emailChangeErrorCopy(l10n, 'same_email'), l10n.emailChangeErrorsSameEmail);
    expect(emailChangeErrorCopy(l10n, 'email_banned'), l10n.emailChangeErrorsEmailBanned);
    expect(emailChangeErrorCopy(l10n, 'email_in_use'), l10n.emailChangeErrorsEmailInUse);
    expect(emailChangeErrorCopy(l10n, 'failed'), l10n.emailChangeErrorsFailed);
    expect(emailChangeErrorCopy(l10n, 'validation_failed'), l10n.emailChangeErrorsInvalidEmail);
  });

  test('unlink codes map to the sign-in methods copy', () {
    expect(unlinkErrorCopy(l10n, 'wrong_password'), l10n.signInMethodsErrorsWrongPassword);
    expect(unlinkErrorCopy(l10n, 'last_identity'), l10n.signInMethodsErrorsLastIdentity);
    expect(unlinkErrorCopy(l10n, 'not_linked'), l10n.signInMethodsErrorsNotLinked);
    expect(unlinkErrorCopy(l10n, 'linking_unavailable'), l10n.mobileSettingsLinkingUnavailable);
    expect(unlinkErrorCopy(l10n, 'failed'), l10n.signInMethodsErrorsFailed);
  });

  test('phone codes map to the mobile settings copy', () {
    expect(phoneErrorCopy(l10n, 'phone_invalid'), l10n.mobileSettingsPhoneErrorInvalid);
    expect(phoneErrorCopy(l10n, 'phone_cooldown'), l10n.mobileSettingsPhoneErrorCooldown);
    expect(phoneErrorCopy(l10n, 'phone_daily_limit'), l10n.mobileSettingsPhoneErrorDailyLimit);
    expect(phoneErrorCopy(l10n, 'phone_send_failed'), l10n.mobileSettingsPhoneErrorSendFailed);
    expect(phoneErrorCopy(l10n, 'phone_unavailable'), l10n.mobileSettingsPhoneUnavailable);
    expect(phoneErrorCopy(l10n, 'phone_code_invalid'), l10n.mobileSettingsPhoneErrorCodeInvalid);
    expect(phoneErrorCopy(l10n, 'phone_code_missing'), l10n.mobileSettingsPhoneErrorCodeMissing);
    expect(phoneErrorCopy(l10n, 'phone_code_expired'), l10n.mobileSettingsPhoneErrorCodeExpired);
    expect(phoneErrorCopy(l10n, 'phone_code_wrong'), l10n.mobileSettingsPhoneErrorCodeWrong);
    expect(phoneErrorCopy(l10n, 'phone_attempts_exceeded'), l10n.mobileSettingsPhoneErrorAttempts);
  });

  test('shared fallbacks: rate limit, network and anything unknown', () {
    for (final f in [emailChangeErrorCopy, unlinkErrorCopy, phoneErrorCopy]) {
      expect(f(l10n, 'reauth_rate_limited'), l10n.mobileSettingsReauthRateLimited);
      expect(f(l10n, 'network'), l10n.mobileSettingsNetworkError);
      expect(f(l10n, 'a_code_from_the_future'), l10n.mobileSettingsGenericError);
    }
    expect(genericAccountErrorCopy(l10n, 'network'), l10n.mobileSettingsNetworkError);
    expect(genericAccountErrorCopy(l10n, 'x'), l10n.mobileSettingsGenericError);
  });
}
