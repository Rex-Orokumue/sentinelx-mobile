import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/phone_screen.dart';
import 'package:sentinelx_mobile/features/onboarding/onboarding_phone_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _PendingResendRepository extends FakeAccountRepository {
  final resend = Completer<PhoneCodeTicket>();
  var sends = 0;

  @override
  Future<PhoneCodeTicket> requestPhoneCode(String phone) {
    sends++;
    if (sends == 2) return resend.future;
    return Future.value(PhoneCodeTicket(
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      resendAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    ));
  }
}

Future<void> _pump(WidgetTester tester, Widget home, FakeAccountRepository repo) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => home),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings -> Phone shows the masked number once verified, never the form', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(phone: AccountPhone(masked: '••••••678', verifiedAt: DateTime.utc(2026, 10, 1)));
    await _pump(tester, const PhoneScreen(), repo);
    final l10n = AppLocalizations.of(tester.element(find.byType(PhoneScreen)));
    expect(find.text(l10n.mobileSettingsPhoneVerified('••••••678')), findsOneWidget);
    expect(find.byKey(const Key('phone-number')), findsNothing);
  });

  testWidgets('Settings -> Phone shows the form when not verified', (tester) async {
    await _pump(tester, const PhoneScreen(), FakeAccountRepository());
    expect(find.byKey(const Key('phone-number')), findsOneWidget);
  });

  testWidgets('resend keeps the code step visible and the number disabled', (tester) async {
    final repo = _PendingResendRepository();
    await _pump(tester, const PhoneScreen(), repo);
    await tester.enterText(find.byKey(const Key('phone-number')), '+2348012345678');
    await tester.tap(find.byKey(const Key('phone-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-code')), findsOneWidget);

    await tester.tap(find.byKey(const Key('phone-resend')));
    await tester.pump();
    expect(repo.sends, 2);
    expect(find.byKey(const Key('phone-code')), findsOneWidget);
    expect(find.byKey(const Key('phone-send')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('phone-number'))).enabled, isFalse);
    expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNull);

    repo.resend.complete(PhoneCodeTicket(
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      resendAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
    ));
    await tester.pump();
    expect(find.byKey(const Key('phone-code')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('phone-number'))).enabled, isFalse);
  });

  testWidgets('the onboarding gate screen has the form, no back button and no skip', (tester) async {
    await _pump(tester, const OnboardingPhoneScreen(), FakeAccountRepository());
    expect(find.byKey(const Key('phone-number')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(const Key('onboarding-phone-skip')), findsNothing);
  });
}
