import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../api/api_client.dart';

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code: $message)';
}

abstract class AuthRepository {
  Future<void> signInWithPassword({required String email, required String password});
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale});
  Future<void> resendConfirmation(String email);
  Future<void> requestReset(String email);
  Future<void> resetPassword(String newPassword);
  Future<String> claimUsername(String username);
  Future<void> signOut();
}

// Tier 1 for the two calls Supabase Auth itself already guards
// (signInWithPassword, updateUser after a verifyOtp-established session) and
// signOut; every other mutation is Tier 3 through ApiClient — never a direct
// `supabase.auth.signUp`, which skips the ban/retired-username/locale logic
// (master spec §2.4).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._api);

  final GoTrueClient _auth;
  final ApiClient _api;

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthApiException catch (e) {
      throw AuthException(e.code ?? 'invalid_credentials', e.message);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    String? ref,
    String? locale,
  }) async {
    try {
      await _api.postAuthSignup(username: username, email: email, password: password, ref: ref, locale: locale);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> resendConfirmation(String email) => _guard(() => _api.postAuthResendConfirmation(email));

  @override
  Future<void> requestReset(String email) => _guard(() => _api.postAuthRequestReset(email));

  @override
  Future<void> resetPassword(String newPassword) => _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<String> claimUsername(String username) async {
    try {
      return await _api.postOnboardingUsername(username);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    } on AuthApiException catch (e) {
      throw AuthException(e.code ?? 'reset_failed', e.message);
    }
  }
}
