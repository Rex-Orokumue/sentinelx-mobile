import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPassword;
  Object? throwOnSignIn;
  bool loggedIn = false;

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (throwOnSignIn != null) throw throwOnSignIn!;
    loggedIn = true;
  }

  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> requestReset(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signOut() async {}
}

Future<void> _pump(WidgetTester tester, _FakeAuthRepository repo, {VoidCallback? onLoggedIn}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(onLoggedIn: onLoggedIn ?? () {}, onForgotPassword: () {}, onCreateAccount: () {}),
    ),
  ));
}

void main() {
  testWidgets('submits email and password, then calls onLoggedIn', (tester) async {
    final repo = _FakeAuthRepository();
    var loggedIn = false;
    await _pump(tester, repo, onLoggedIn: () => loggedIn = true);

    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'a@b.com');
    expect(repo.lastPassword, 'password123');
    expect(loggedIn, isTrue);
  });

  testWidgets('shows a translated error and does not call onLoggedIn on failure', (tester) async {
    final repo = _FakeAuthRepository()..throwOnSignIn = const AuthException('invalid_credentials', 'x');
    var loggedIn = false;
    await _pump(tester, repo, onLoggedIn: () => loggedIn = true);

    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(loggedIn, isFalse);
  });

  testWidgets('offers a resend button when the account exists but is unconfirmed', (tester) async {
    final repo = _FakeAuthRepository()..throwOnSignIn = const AuthException('email_not_confirmed', 'x');
    await _pump(tester, repo);
    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-resend')), findsOneWidget);
  });
}
