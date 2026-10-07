import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';

MyAccount testAccount({
  DeletionState? deletion,
  String? email = 'ada@example.com',
  String? pendingEmail,
  bool passwordIdentity = true,
  bool google = false,
  AccountPhone? phone,
  String? locale = 'en',
}) =>
    MyAccount(
      deletion: deletion,
      signIn: AccountSignIn(email: email, pendingEmail: pendingEmail, passwordIdentity: passwordIdentity, google: google),
      phone: phone,
      locale: locale,
    );

/// Records every call; set a `*Error` to make that call throw it, or `*Result` to change what it returns.
class FakeAccountRepository implements AccountRepository {
  MyAccount accountResult = testAccount();
  final calls = <String>[];
  Object? accountError;
  Object? deletionError;
  Object? cancelError;
  Object? deleteNowError;
  Object? phoneCodeError;
  Object? phoneConfirmError;
  Object? emailError;
  Object? unlinkError;
  Object? localeError;
  PhoneCodeTicket phoneTicket = PhoneCodeTicket(
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    resendAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
  );
  String? lastEmail;
  String? lastPassword;
  String? lastLocale;
  String? lastPhone;
  String? lastCode;
  String? lastUsername;

  @override
  Future<MyAccount> account() async {
    calls.add('account');
    if (accountError != null) throw accountError!;
    return accountResult;
  }

  @override
  Future<DeletionTicket> requestDeletion() async {
    calls.add('requestDeletion');
    if (deletionError != null) throw deletionError!;
    final now = DateTime.now().toUtc();
    return DeletionTicket(requestedAt: now, dueAt: now.add(const Duration(days: 15)));
  }

  @override
  Future<void> cancelDeletion() async {
    calls.add('cancelDeletion');
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> deleteNow(String username) async {
    calls.add('deleteNow');
    lastUsername = username;
    if (deleteNowError != null) throw deleteNowError!;
  }

  @override
  Future<PhoneCodeTicket> requestPhoneCode(String phone) async {
    calls.add('requestPhoneCode');
    lastPhone = phone;
    if (phoneCodeError != null) throw phoneCodeError!;
    return phoneTicket;
  }

  @override
  Future<DateTime> confirmPhoneCode(String code) async {
    calls.add('confirmPhoneCode');
    lastCode = code;
    if (phoneConfirmError != null) throw phoneConfirmError!;
    return DateTime.now().toUtc();
  }

  @override
  Future<String> changeEmail({required String email, required String password}) async {
    calls.add('changeEmail');
    lastEmail = email;
    lastPassword = password;
    if (emailError != null) throw emailError!;
    return email.toLowerCase();
  }

  @override
  Future<void> unlinkGoogle(String password) async {
    calls.add('unlinkGoogle');
    lastPassword = password;
    if (unlinkError != null) throw unlinkError!;
  }

  @override
  Future<String> setLocale(String locale) async {
    calls.add('setLocale');
    lastLocale = locale;
    if (localeError != null) throw localeError!;
    return locale;
  }
}
