import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_fr.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/language_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/locale_providers.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_local_kv.dart';

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

Future<void> _pump(WidgetTester tester, FakeAccountRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      localKvProvider.overrideWith((ref) async => MemoryLocalKv()),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => _me()),
    ],
    child: Consumer(builder: (context, ref, _) {
      return MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LanguageScreen(),
      );
    }),
  ));
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String code) {
  final group = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
  return group.groupValue == code;
}

void main() {
  testWidgets('lists the three languages with the current one selected', (tester) async {
    await _pump(tester, FakeAccountRepository());
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Pidgin'), findsOneWidget);
    expect(_selected(tester, 'en'), isTrue);
  });

  testWidgets('choosing a language saves it and the whole app switches', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('language-fr')));
    await tester.pumpAndSettle();
    expect(repo.lastLocale, 'fr');
    expect(_selected(tester, 'fr'), isTrue);
    // The screen itself is now French.
    expect(find.text(AppLocalizationsFr().mobileSettingsLanguageTitle), findsWidgets);
  });

  testWidgets('a failed save shows the failure message and keeps the old language', (tester) async {
    final repo = FakeAccountRepository()..localeError = const ApiException(status: 500, code: 'locale_save_failed', message: 'x');
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('language-pcm')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(_selected(tester, 'en'), isTrue);
  });
}
