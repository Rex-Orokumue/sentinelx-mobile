import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/delete_account_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/deletion_banner_host.dart';
import 'package:sentinelx_mobile/features/account/settings/language_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/phone_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/security_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/sign_in_methods_screen.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_local_kv.dart';

MeResponse _me(String locale, {bool deletionPending = false}) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: locale,
        membershipTier: null, kycVerified: false,
        deletionRequestedAt: deletionPending ? '2026-10-05T00:00:00.000Z' : null,
      ),
    );

Future<void> _pump(WidgetTester tester, Widget screen, String locale, {bool banner = false}) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeAccountRepository()
    ..accountResult = testAccount(
      locale: locale,
      deletion: banner
          ? DeletionState(requestedAt: DateTime.utc(2026, 10, 5), dueAt: DateTime.utc(2026, 10, 20), daysRemaining: 13)
          : null,
    );
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      localKvProvider.overrideWith((ref) async => MemoryLocalKv()),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => _me(locale, deletionPending: banner)),
    ],
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: banner ? (context, child) => DeletionBannerHost(child: child!) : null,
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['fr', 'pcm']) {
    for (final (name, screen) in <(String, Widget)>[
      ('Language', const LanguageScreen()),
      ('Security', const SecurityScreen()),
      ('Sign-in methods', const SignInMethodsScreen()),
      ('Phone', const PhoneScreen()),
      ('Delete account', const DeleteAccountScreen()),
    ]) {
      testWidgets('$name has no overflow at 320 px in $locale', (tester) async {
        await _pump(tester, screen, locale);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('deletion banner has no overflow at 320 px in $locale', (tester) async {
      await _pump(tester, const Scaffold(body: Text('APP')), locale, banner: true);
      expect(find.byKey(const Key('deletion-banner')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
