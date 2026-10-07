import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/phone_verify_form.dart';

import '../../../fakes/fake_account_repository.dart';

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, {VoidCallback? onVerified}) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: PhoneVerifyForm(onVerified: onVerified ?? () {}))),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(PhoneVerifyForm)));
}

Future<void> _sendCode(WidgetTester tester, {String phone = '08012345678'}) async {
  await tester.enterText(find.byKey(const Key('phone-number')), phone);
  await tester.tap(find.byKey(const Key('phone-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sending a code reveals the code field and a resend countdown', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    expect(find.byKey(const Key('phone-code')), findsNothing);
    await _sendCode(tester);
    expect(repo.lastPhone, '08012345678');
    expect(find.byKey(const Key('phone-code')), findsOneWidget);
    expect(find.byKey(const Key('phone-resend')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNull); // counting down
    expect(find.textContaining('Resend in'), findsOneWidget);
  });

  testWidgets('the countdown ends and Resend becomes available', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await _sendCode(tester);
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNotNull);
  });

  testWidgets('a server cooldown starts the countdown from retryAfterSeconds and keeps the number step', (tester) async {
    final repo = FakeAccountRepository()
      ..phoneCodeError = const ApiException(status: 429, code: 'phone_cooldown', message: 'x', fields: {'retryAfterSeconds': '40'});
    final l10n = await _pump(tester, repo);
    await _sendCode(tester);
    expect(find.text(l10n.mobileSettingsPhoneErrorCooldown), findsOneWidget);
    expect(find.byKey(const Key('phone-code')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('phone-send'))).onPressed, isNull); // waits out the 40 s
    await tester.pump(const Duration(seconds: 41));
    expect(tester.widget<FilledButton>(find.byKey(const Key('phone-send'))).onPressed, isNotNull);
  });

  testWidgets('phone_unavailable shows the fixed message with no retry loop', (tester) async {
    final repo = FakeAccountRepository()..phoneCodeError = const ApiException(status: 503, code: 'phone_unavailable', message: 'x');
    final l10n = await _pump(tester, repo);
    await _sendCode(tester);
    expect(find.text(l10n.mobileSettingsPhoneUnavailable), findsOneWidget);
    expect(find.byKey(const Key('phone-send')), findsNothing);
  });

  testWidgets('an invalid number shows the invalid-number message', (tester) async {
    final repo = FakeAccountRepository()..phoneCodeError = const ApiException(status: 400, code: 'phone_invalid', message: 'x');
    final l10n = await _pump(tester, repo);
    await _sendCode(tester, phone: 'abc');
    expect(find.text(l10n.mobileSettingsPhoneErrorInvalid), findsOneWidget);
  });

  testWidgets('a wrong code shows the message and stays; the right code verifies and calls back', (tester) async {
    final repo = FakeAccountRepository();
    var verified = 0;
    final l10n = await _pump(tester, repo, onVerified: () => verified++);
    await _sendCode(tester);

    repo.phoneConfirmError = const ApiException(status: 400, code: 'phone_code_wrong', message: 'x');
    await tester.enterText(find.byKey(const Key('phone-code')), '000000');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsPhoneErrorCodeWrong), findsOneWidget);
    expect(verified, 0);

    repo.phoneConfirmError = null;
    await tester.enterText(find.byKey(const Key('phone-code')), '123456');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(repo.lastCode, '123456');
    expect(verified, 1);
  });

  testWidgets('a malformed code never reaches the server', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await _sendCode(tester);
    await tester.enterText(find.byKey(const Key('phone-code')), '12');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'confirmPhoneCode'), isEmpty);
  });
}
