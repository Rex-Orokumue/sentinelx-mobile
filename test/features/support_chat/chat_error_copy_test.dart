import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_error_copy.dart';

void main() {
// test/features/support_chat/chat_error_copy_test.dart
test('every known code has copy, unknown codes use the generic copy, signed-out unavailable differs', () async {
  final l = await AppLocalizations.delegate.load(const Locale('en'));
  for (final code in ['chat_rate_limited', 'chat_unavailable', 'unauthorized', 'chat_truncated', 'network', 'clear_failed', 'chat_upstream', 'internal']) {
    expect(chatErrorMessage(l, code, signedIn: true, retryAfterSeconds: 7), isNotEmpty, reason: code);
  }
  expect(chatErrorMessage(l, 'something_new', signedIn: true), chatErrorMessage(l, 'internal', signedIn: true));
  expect(chatErrorMessage(l, 'chat_unavailable', signedIn: false), isNot(chatErrorMessage(l, 'chat_unavailable', signedIn: true)));
});
}
