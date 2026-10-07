import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/security_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _FakeAuth implements AuthRepository {
  String? resetFor;
  Object? resetError;
  @override
  Future<void> requestReset(String email) async {
    if (resetError != null) throw resetError!;
    resetFor = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, _FakeAuth auth) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(auth),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SecurityScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(SecurityScreen)));
}

Future<void> _openSheetAndFill(WidgetTester tester, {String email = 'new@example.com', String password = 'pw'}) async {
  await tester.tap(find.byKey(const Key('security-change-email')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('security-new-email')), email);
  await tester.enterText(find.byKey(const Key('security-password')), password);
}

void main() {
  testWidgets('shows the current address and a pending change', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(pendingEmail: 'next@example.com');
    final l10n = await _pump(tester, repo, _FakeAuth());
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(l10n.emailChangePending('next@example.com')), findsOneWidget);
    expect(find.text(l10n.emailChangePendingHint), findsOneWidget);
  });

  testWidgets('submitting sends the email and password, then tells the user to check the inbox', (tester) async {
    final repo = FakeAccountRepository();
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(repo.lastEmail, 'new@example.com');
    expect(repo.lastPassword, 'pw');
    expect(find.text(l10n.emailChangeSent('new@example.com')), findsOneWidget);
  });

  testWidgets('a wrong password stays on the sheet with the inline message', (tester) async {
    final repo = FakeAccountRepository()..emailError = const ApiException(status: 400, code: 'wrong_password', message: 'x');
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emailChangeErrorsWrongPassword), findsOneWidget);
    expect(find.byKey(const Key('security-password')), findsOneWidget); // still on the sheet
  });

  testWidgets('empty fields never reach the server', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeAuth());
    await tester.tap(find.byKey(const Key('security-change-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'changeEmail'), isEmpty);
  });

  testWidgets('a rate limit shows the too-many-attempts message', (tester) async {
    final repo = FakeAccountRepository()
      ..emailError = const ApiException(status: 429, code: 'reauth_rate_limited', message: 'x', fields: {'retryAfterSeconds': '300'});
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsReauthRateLimited), findsOneWidget);
  });

  testWidgets('reset password emails a link to the current address', (tester) async {
    final auth = _FakeAuth();
    final l10n = await _pump(tester, FakeAccountRepository(), auth);
    await tester.tap(find.byKey(const Key('security-reset-password')));
    await tester.pumpAndSettle();
    expect(auth.resetFor, 'ada@example.com');
    expect(find.text(l10n.mobileSettingsSecurityResetSent), findsOneWidget);
  });

  testWidgets('a failed reset shows the generic message, not server text', (tester) async {
    final auth = _FakeAuth()..resetError = const ApiException(status: 0, code: 'network', message: 'offline');
    final l10n = await _pump(tester, FakeAccountRepository(), auth);
    await tester.tap(find.byKey(const Key('security-reset-password')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsNetworkError), findsOneWidget);
  });
}
