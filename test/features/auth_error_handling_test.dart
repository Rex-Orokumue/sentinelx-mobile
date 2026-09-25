import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/forgot_password_screen.dart';
import 'package:sentinelx_mobile/features/auth/google_sign_in_button.dart';
import 'package:sentinelx_mobile/features/auth/login_screen.dart';
import 'package:sentinelx_mobile/features/auth/reset_password_screen.dart';

// Every method throws whatever is configured for it; everything else succeeds.
class _ThrowingAuthRepository implements AuthRepository {
  Object? onSignIn;
  Object? onResend;
  Object? onRequestReset;
  Object? onResetPassword;
  Object? onGoogle;

  Future<void> _maybe(Object? e) async {
    if (e != null) throw e;
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) => _maybe(onSignIn);
  @override
  Future<void> resendConfirmation(String email) => _maybe(onResend);
  @override
  Future<void> requestReset(String email) => _maybe(onRequestReset);
  @override
  Future<void> resetPassword(String newPassword) => _maybe(onResetPassword);
  @override
  Future<void> signInWithGoogle() => _maybe(onGoogle);
  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signOut() async {}
}

Future<void> _pump(WidgetTester tester, AuthRepository repo, Widget home) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
}

void main() {
  testWidgets('login: a non-AuthException failure shows the generic error and re-enables submit', (tester) async {
    final repo = _ThrowingAuthRepository()..onSignIn = Exception('boom');
    await _pump(tester, repo, LoginScreen(onLoggedIn: () {}, onForgotPassword: () {}, onCreateAccount: () {}));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong creating your account. Please try again.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('login-submit'))).onPressed, isNotNull);
  });

  testWidgets('login: a failed resend shows an error instead of throwing', (tester) async {
    final repo = _ThrowingAuthRepository()
      ..onSignIn = const AuthException('email_not_confirmed', 'x')
      ..onResend = Exception('network');
    await _pump(tester, repo, LoginScreen(onLoggedIn: () {}, onForgotPassword: () {}, onCreateAccount: () {}));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-resend')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not resend the confirmation link. Please try again.'), findsOneWidget);
  });

  testWidgets('forgot password: a failure shows an error instead of throwing', (tester) async {
    final repo = _ThrowingAuthRepository()..onRequestReset = Exception('network');
    await _pump(tester, repo, const ForgotPasswordScreen());
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not send the reset link. Please try again.'), findsOneWidget);
  });

  testWidgets('reset password: a failure shows an error instead of throwing', (tester) async {
    final repo = _ThrowingAuthRepository()..onResetPassword = Exception('expired');
    await _pump(tester, repo, ResetPasswordScreen(onDone: () {}));
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not update your password. Please try again.'), findsOneWidget);
  });

  testWidgets('google: shows localized copy, never the raw exception message', (tester) async {
    final repo = _ThrowingAuthRepository()..onGoogle = const AuthException('google_sign_in_failed', 'RAW SDK TEXT');
    await _pump(tester, repo, Scaffold(body: GoogleSignInButton(onSignedIn: () {})));
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('RAW SDK TEXT'), findsNothing);
    expect(find.text('Google sign-in failed. Please try again.'), findsOneWidget);
  });

  testWidgets('google: a canceled sign-in shows no error and an unexpected error is caught', (tester) async {
    final repo = _ThrowingAuthRepository()..onGoogle = const AuthException('google_canceled', 'Sign-in was canceled.');
    await _pump(tester, repo, Scaffold(body: GoogleSignInButton(onSignedIn: () {})));
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in was canceled.'), findsNothing);
    repo.onGoogle = Exception('weird');
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Google sign-in failed. Please try again.'), findsOneWidget);
  });
}
