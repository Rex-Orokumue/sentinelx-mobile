import 'package:sentinelx_mobile/core/auth/auth_repository.dart';

class FakeAuthRepositoryForForgot implements AuthRepository {
  String? lastEmail;

  @override
  Future<void> requestReset(String email) async => lastEmail = email;
  @override
  Future<void> signInWithPassword({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signOut() async {}
}
