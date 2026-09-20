import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:sentinelx_mobile/core/auth/email_link_handler.dart';

// implements + noSuchMethod: same pattern as auth_repository_test.dart's
// _FakeAuth — GoTrueClient is a concrete SDK class with many members this
// handler never touches.
class _FakeAuth implements GoTrueClient {
  Map<String, Object?>? lastVerify;
  bool fail = false;

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    lastVerify = {'type': type, 'tokenHash': tokenHash};
    if (fail) throw Exception('bad token');
    return AuthResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a recovery link calls verifyOtp with type=recovery and reports outcome=recovery', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=abc123&type=recovery'),
      auth: auth,
    );
    expect(auth.lastVerify?['tokenHash'], 'abc123');
    expect(result.outcome, EmailLinkOutcome.recovery);
  });

  test('a signup confirmation link reports outcome=verified', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=xyz&type=signup'),
      auth: auth,
    );
    expect(result.outcome, EmailLinkOutcome.verified);
  });

  test('a locale-prefixed link (fr/pcm) is still handled', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=xyz&type=email_change'),
      auth: auth,
    );
    expect(result.outcome, EmailLinkOutcome.verified);
  });

  test('a missing token_hash or type reports failed without calling verifyOtp', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(Uri.parse('https://sentinelxesports.com.ng/auth/confirm'), auth: auth);
    expect(result.outcome, EmailLinkOutcome.failed);
    expect(auth.lastVerify, isNull);
  });

  test('a verifyOtp failure (expired/used link) reports failed', () async {
    final auth = _FakeAuth()..fail = true;
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=abc&type=signup'),
      auth: auth,
    );
    expect(result.outcome, EmailLinkOutcome.failed);
  });
}
