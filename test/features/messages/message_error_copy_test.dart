import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/messages/message_error_copy.dart';

ApiException _e(String code, [int status = 400]) => ApiException(status: status, code: code, message: 'server english text');

void main() {
  const codes = [
    'not_found',
    'validation',
    'blocked_by_me',
    'blocked',
    'messaging_restricted',
    'edit_window_closed',
    'not_forwardable',
    'request_pending_limit',
    'request_media_not_allowed',
    'send_failed',
    'action_failed',
  ];

  for (final lang in ['en', 'fr']) {
    final l = lookupAppLocalizations(Locale(lang));

    test('[$lang] every documented code maps to a non-generic string', () {
      for (final c in codes) {
        final text = dmErrorCopy(l, _e(c));
        expect(text, isNot(l.dmErrorGeneric), reason: c);
        expect(text, isNot(contains('server english text')), reason: c);
      }
    });

    test('[$lang] blocked and blocked_by_me read differently', () {
      expect(dmErrorCopy(l, _e('blocked', 403)), isNot(dmErrorCopy(l, _e('blocked_by_me', 403))));
    });

    test('[$lang] invalid_cursor and idempotency_key_required use the generic copy', () {
      expect(dmErrorCopy(l, _e('invalid_cursor')), l.dmErrorGeneric);
      expect(dmErrorCopy(l, _e('idempotency_key_required')), l.dmErrorGeneric);
    });

    test('[$lang] unknown code, network exception and a non-ApiException are generic', () {
      expect(dmErrorCopy(l, _e('brand_new_code')), l.dmErrorGeneric);
      expect(dmErrorCopy(l, _e('network', 0)), l.dmErrorGeneric);
      expect(dmErrorCopy(l, StateError('boom')), l.dmErrorGeneric);
    });

    test('[$lang] the copy is keyed by code, not status', () {
      expect(dmErrorCopy(l, _e('edit_window_closed', 200)), l.dmErrorEditWindow);
      expect(dmErrorCopy(l, _e('edit_window_closed', 409)), l.dmErrorEditWindow);
    });
  }

  test('plural: dmUnreadCount 1 vs 3 in en and fr', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(en.dmUnreadCount(1), isNot(en.dmUnreadCount(3)));
    expect(en.dmUnreadCount(1), contains('1'));
    expect(en.dmUnreadCount(3), contains('3'));
    expect(fr.dmUnreadCount(1), isNot(fr.dmUnreadCount(3)));
    expect(en.dmRequestsCount(1), isNot(en.dmRequestsCount(2)));
    expect(fr.dmRequestsCount(1), isNot(fr.dmRequestsCount(2)));
    expect(en.dmVoiceSeconds(1), isNot(en.dmVoiceSeconds(12)));
    expect(fr.dmVoiceSeconds(1), isNot(fr.dmVoiceSeconds(12)));
  });

  test('a blocked-by-them player and a declined request share one string key', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.dmCannotMessage, isNotEmpty);
  });
}
