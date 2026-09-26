import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/match/match_error_copy.dart';

const _handled = [
  'network',
  'unauthorized',
  'idempotency_in_progress',
  'upload_failed',
  'match_not_found',
  'not_participant',
  'not_match_day',
  'check_in_closed',
  'bye_no_result',
  'match_cancelled',
  'already_confirmed',
  'submission_locked',
  'screenshot_required',
  'validation_failed',
  'not_a_participant',
  'result_not_confirmed_yet',
  'cannot_rate_self',
  'not_ratable',
  'already_rated',
  'pending_deletion',
  'own_match',
  'invalid_pick',
  'window_closed',
  'insufficient_coins',
  'not_in_lobby',
  'lobby_confirmed',
  'result_confirmed',
];

void main() {
  final l10n = AppLocalizationsEn();

  test('every handled code has specific, non-empty copy', () {
    final outputs = <String>{};
    for (final code in _handled) {
      final copy = matchErrorCopy(l10n, code);
      expect(copy, isNotEmpty, reason: code);
      expect(copy, isNot(l10n.mtcEcGeneric), reason: code);
      outputs.add(copy);
    }
    expect(outputs.length, greaterThanOrEqualTo(22));
  });

  test('server-internal and unknown codes fall back to the generic message', () {
    for (final code in ['submit_failed', 'check_in_failed', 'wager_failed', 'something_new', '']) {
      expect(matchErrorCopy(l10n, code), l10n.mtcEcGeneric, reason: code);
    }
  });
}
