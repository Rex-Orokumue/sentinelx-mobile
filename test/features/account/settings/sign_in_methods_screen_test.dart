import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/google_linker.dart';
import 'package:sentinelx_mobile/features/account/settings/sign_in_methods_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../fakes/fake_account_repository.dart';

class _FakeLinker implements GoogleLinker {
  int calls = 0;
  Object? error;
  @override
  Future<void> link() async {
    calls++;
    if (error != null) throw error!;
  }
}

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, GoogleLinker linker) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      googleLinkerProvider.overrideWithValue(linker),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignInMethodsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(SignInMethodsScreen)));
}

void main() {
  testWidgets('not linked: shows Link Google and starts the browser round-trip', (tester) async {
    final linker = _FakeLinker();
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    expect(find.text(l10n.signInMethodsNotLinked), findsOneWidget);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(linker.calls, 1);
    expect(find.byKey(const Key('signin-link-error')), findsNothing); // a cancelled round-trip shows no error
  });

  testWidgets('a link attempt that throws shows the link-failed message', (tester) async {
    final linker = _FakeLinker()..error = StateError('launch failed');
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsLinkFailed), findsOneWidget);
  });

  testWidgets('manual linking disabled shows the unavailable message, not a retry prompt', (tester) async {
    final linker = _FakeLinker()
      ..error = const supabase.AuthException('Linking unavailable', code: 'manual_linking_disabled');
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsLinkingUnavailable), findsOneWidget);
  });

  testWidgets('a browser launch that returns false shows the link-failed message', (tester) async {
    final l10n = await _pump(tester, FakeAccountRepository(), SupabaseGoogleLinker(() async => false));
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsLinkFailed), findsOneWidget);
  });

  testWidgets('an untyped error mentioning manual linking uses the generic failure copy', (tester) async {
    final linker = _FakeLinker()..error = StateError('manual_linking_disabled appears in message');
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsLinkFailed), findsOneWidget);
  });

  testWidgets('coming back from the browser round-trip refetches the account so a successful link shows', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeLinker());
    final before = repo.calls.where((c) => c == 'account').length;
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    repo.accountResult = testAccount(google: true); // what the refetch will see after a successful link
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'account').length, before + 1);
    expect(find.byKey(const Key('signin-link-google')), findsNothing);
    expect(find.byKey(const Key('signin-unlink-google')), findsOneWidget);
  });

  testWidgets('resuming the app without a link attempt does not refetch', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeLinker());
    final before = repo.calls.where((c) => c == 'account').length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'account').length, before);
  });

  testWidgets('linked with a password: Unlink asks for the password then calls the server', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(google: true, passwordIdentity: true);
    final l10n = await _pump(tester, repo, _FakeLinker());
    expect(find.text(l10n.signInMethodsLinked), findsWidgets);
    await tester.tap(find.byKey(const Key('signin-unlink-google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('password-sheet-field')), 'pw');
    repo.accountResult = testAccount(google: false, passwordIdentity: true); // what the refetch will see
    await tester.tap(find.byKey(const Key('password-sheet-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('unlinkGoogle'));
    expect(repo.lastPassword, 'pw');
    expect(find.byKey(const Key('signin-link-google')), findsOneWidget); // refreshed: now offers Link
  });

  testWidgets('a wrong password stays on the sheet', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(google: true)
      ..unlinkError = const ApiException(status: 400, code: 'wrong_password', message: 'x');
    final l10n = await _pump(tester, repo, _FakeLinker());
    await tester.tap(find.byKey(const Key('signin-unlink-google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('password-sheet-field')), 'nope');
    await tester.tap(find.byKey(const Key('password-sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsErrorsWrongPassword), findsOneWidget);
  });

  testWidgets('the only sign-in method cannot be unlinked and says why', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(google: true, passwordIdentity: false);
    final l10n = await _pump(tester, repo, _FakeLinker());
    expect(find.byKey(const Key('signin-unlink-google')), findsNothing);
    expect(find.text(l10n.signInMethodsOnlyMethod), findsOneWidget);
  });
}
