import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/account_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// Everything the Settings screens read and write. A seam over [ApiClient] so screens are tested against a
/// fake; there is no direct Supabase access here (every write is a Tier 3 API call).
abstract class AccountRepository {
  Future<MyAccount> account();
  Future<DeletionTicket> requestDeletion();
  Future<void> cancelDeletion();
  Future<void> deleteNow(String username);
  Future<PhoneCodeTicket> requestPhoneCode(String phone);
  Future<DateTime> confirmPhoneCode(String code);
  Future<String> changeEmail({required String email, required String password});
  Future<void> unlinkGoogle(String password);
  Future<String> setLocale(String locale);
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._api);
  final ApiClient _api;

  @override
  Future<MyAccount> account() => _api.getMyAccount();
  @override
  Future<DeletionTicket> requestDeletion() => _api.postAccountDeletion();
  @override
  Future<void> cancelDeletion() => _api.deleteAccountDeletion();
  @override
  Future<void> deleteNow(String username) => _api.postAccountDeletionExecute(username);
  @override
  Future<PhoneCodeTicket> requestPhoneCode(String phone) => _api.postPhoneCode(phone);
  @override
  Future<DateTime> confirmPhoneCode(String code) => _api.postPhoneConfirm(code);
  @override
  Future<String> changeEmail({required String email, required String password}) => _api.postMyEmail(email: email, password: password);
  @override
  Future<void> unlinkGoogle(String password) => _api.deleteGoogleIdentity(password);
  @override
  Future<String> setLocale(String locale) => _api.putMyLocale(locale);
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => ApiAccountRepository(ref.watch(apiClientProvider)));

/// The caller's account (deletion, sign-in methods, phone). Null when signed out, with no request made.
/// Keyed on [viewerIdProvider] so a token refresh never refetches and a different user never sees the last
/// user's data.
final myAccountProvider = FutureProvider.autoDispose<MyAccount?>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(accountRepositoryProvider).account();
});
