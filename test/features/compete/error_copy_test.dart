import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/compete/error_copy.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps every registration, waitlist, invitation and profile code to specific copy', () {
    const codes = [
      'network', 'unauthorized', 'tournament_not_found', 'rules_agreement_required', 'already_registered',
      'tournament_full', 'invitation_only', 'registration_closed', 'insufficient_coins', 'payment_init_failed',
      'waitlist_not_open', 'already_on_waitlist', 'idempotency_in_progress', 'invitation_not_found',
      'invitation_no_longer_available', 'invitation_expired', 'username_taken', 'username_locked', 'save_failed',
    ];
    final seen = <String>{};
    for (final c in codes) {
      final text = errorCopy(l10n, c);
      expect(text, isNotEmpty, reason: c);
      expect(text, isNot(l10n.cmpEcGeneric), reason: '$c fell through to the generic message');
      seen.add(text);
    }
    expect(seen.length, greaterThan(15));
  });

  test('unknown and server-only codes fall back to the generic message', () {
    expect(errorCopy(l10n, 'something_new'), l10n.cmpEcGeneric);
    expect(errorCopy(l10n, 'registration_failed'), l10n.cmpEcGeneric);
    expect(errorCopy(l10n, ''), l10n.cmpEcGeneric);
  });
}
