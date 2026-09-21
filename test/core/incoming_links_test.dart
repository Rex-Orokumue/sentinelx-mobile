import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/incoming_links.dart';

void main() {
  group('isAuthConfirmPath', () {
    test('matches the bare path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('matches a locale-prefixed path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('does not match other paths', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/tournaments')), isFalse);
    });
  });
}
