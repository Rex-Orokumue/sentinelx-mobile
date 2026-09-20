import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/signup_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingSignup extends FakeAuthRepositoryForForgot {
  Map<String, Object?>? args;
  Object? throwOnSignUp;

  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {
    args = {'username': username, 'email': email, 'password': password, 'ref': ref, 'locale': locale};
    if (throwOnSignUp != null) throw throwOnSignUp!;
  }
}

Future<void> _pump(WidgetTester tester, _RecordingSignup repo, {String? initialRef, void Function(String email)? onSignedUp}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignupScreen(onSignedUp: onSignedUp ?? (_) {}, onLogIn: () {}, initialRef: initialRef),
    ),
  ));
}

void main() {
  testWidgets('submits username, email, password and calls onSignedUp with the email', (tester) async {
    final repo = _RecordingSignup();
    String? signedUpEmail;
    await _pump(tester, repo, onSignedUp: (e) => signedUpEmail = e);

    await tester.enterText(find.byKey(const Key('signup-username')), 'newplayer');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();

    expect(repo.args, {'username': 'newplayer', 'email': 'new@x.com', 'password': 'password123', 'ref': null, 'locale': 'en'});
    expect(signedUpEmail, 'new@x.com');
  });

  testWidgets('passes the initial ref through to signUp', (tester) async {
    final repo = _RecordingSignup();
    await _pump(tester, repo, initialRef: 'friend1');
    await tester.enterText(find.byKey(const Key('signup-username')), 'newplayer');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(repo.args?['ref'], 'friend1');
  });

  testWidgets('shows a translated error on a taken username without leaving the wizard', (tester) async {
    final repo = _RecordingSignup()..throwOnSignUp = const AuthException('username_taken', 'x');
    var signedUp = false;
    await _pump(tester, repo, onSignedUp: (_) => signedUp = true);
    await tester.enterText(find.byKey(const Key('signup-username')), 'taken');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That username is taken — try another.'), findsOneWidget);
    expect(signedUp, isFalse);
  });
}
