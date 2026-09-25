import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';

class _Recording {
  final calls = <String, List<Object?>>{};
  void record(String name, List<Object?> args) => calls[name] = args;
}

// implements + noSuchMethod: GoTrueClient/ApiClient are concrete SDK/app
// classes with many members this repository never touches. Overriding just
// the handful actually called and falling through to noSuchMethod for the
// rest satisfies the type system without a mocking package (Tech Stack:
// "flutter_test (fakes, no mocking package)") or hand-writing every member.
class _FakeAuth implements GoTrueClient {
  _FakeAuth(this._rec);
  final _Recording _rec;
  Object? failWith;

  @override
  Future<AuthResponse> signInWithPassword({String? email, String? phone, required String password, String? captchaToken}) async {
    _rec.record('signInWithPassword', [email, password]);
    if (failWith != null) throw failWith!;
    return AuthResponse();
  }

  @override
  Future<UserResponse> updateUser(UserAttributes attributes, {String? emailRedirectTo}) async {
    _rec.record('updateUser', [attributes.password]);
    if (failWith != null) throw failWith!;
    return UserResponse.fromJson(const {});
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async => _rec.record('signOut', []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi implements ApiClient {
  _FakeApi(this._rec);
  final _Recording _rec;

  @override
  Future<void> postAuthSignup({required String username, required String email, required String password, String? ref, String? locale}) async {
    _rec.record('postAuthSignup', [username, email, password, ref, locale]);
  }

  @override
  Future<void> postAuthResendConfirmation(String email) async => _rec.record('postAuthResendConfirmation', [email]);
  @override
  Future<void> postAuthRequestReset(String email) async => _rec.record('postAuthRequestReset', [email]);
  @override
  Future<String> postOnboardingUsername(String username) async {
    _rec.record('postOnboardingUsername', [username]);
    return username;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signInWithPassword delegates to Supabase Auth directly (Tier 1)', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    await repo.signInWithPassword(email: 'a@b.com', password: 'password123');
    expect(rec.calls['signInWithPassword'], ['a@b.com', 'password123']);
  });

  test('signUp goes through the API, not Supabase Auth directly', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    await repo.signUp(username: 'new', email: 'a@b.com', password: 'password123', ref: 'x', locale: 'fr');
    expect(rec.calls['postAuthSignup'], ['new', 'a@b.com', 'password123', 'x', 'fr']);
    expect(rec.calls.containsKey('signUp'), isFalse);
  });

  test('resendConfirmation and requestReset go through the API', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    await repo.resendConfirmation('a@b.com');
    await repo.requestReset('a@b.com');
    expect(rec.calls['postAuthResendConfirmation'], ['a@b.com']);
    expect(rec.calls['postAuthRequestReset'], ['a@b.com']);
  });

  test('resetPassword calls Supabase Auth updateUser directly (a session already exists from verifyOtp)', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    await repo.resetPassword('newpassword123');
    expect(rec.calls['updateUser'], ['newpassword123']);
  });

  test('claimUsername goes through the API and returns the claimed username', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    final result = await repo.claimUsername('BrandNew');
    expect(result, 'BrandNew');
    expect(rec.calls['postOnboardingUsername'], ['BrandNew']);
  });

  test('signOut calls Supabase Auth directly', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec));
    await repo.signOut();
    expect(rec.calls['signOut'], []);
  });

  test('maps a Supabase AuthApiException into this app\'s AuthException with the same code', () async {
    final rec = _Recording();
    final fakeAuth = _FakeAuth(rec)..failWith = const AuthApiException('Invalid email or password.', code: 'invalid_credentials');
    final repo = SupabaseAuthRepository(fakeAuth, _FakeApi(rec));
    await expectLater(
      repo.signInWithPassword(email: 'a@b.com', password: 'wrong'),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  });

  test('signInWithGoogle is on the AuthRepository interface', () {
    // Compile-time check: AuthRepository must declare signInWithGoogle().
    // ignore: unused_element, prefer_function_declarations_over_variables
    Future<void> Function(AuthRepository) _ = (r) => r.signInWithGoogle();
  });

  test('signInWithGoogle throws google_not_configured before touching the Google SDK when no client id is set', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec)); // googleWebClientId defaults to ''
    await expectLater(
      repo.signInWithGoogle(),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'google_not_configured')),
    );
  });
}
