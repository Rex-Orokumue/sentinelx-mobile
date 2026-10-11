import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/referrals_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/features/account/referrals/referral_providers.dart';
import 'package:sentinelx_mobile/features/account/referrals/referral_screen.dart';
import 'package:sentinelx_mobile/features/account/referrals/referral_sharing.dart';

final _overview = ReferralOverview(
  username: 'owner',
  shareUrl: 'https://sentinelxesports.com.ng/signup?ref=owner',
  totalReferrals: 2,
  convertedCount: 1,
  totalCoinsEarned: 500,
  nextMilestone: const ReferralMilestone(count: 5, bonusCoins: 500),
  invited: [
    ReferredPlayer(
      id: 'r1',
      name: 'Friend One',
      avatarUrl: null,
      tier: 'recruit',
      frameUrl: null,
      status: 'converted',
      date: DateTime.utc(2026, 10, 10),
      coinsAwarded: 250,
    ),
    ReferredPlayer(
      id: 'r2',
      name: 'Friend Two',
      avatarUrl: null,
      tier: 'recruit',
      frameUrl: null,
      status: 'pending',
      date: DateTime.utc(2026, 10, 10),
      coinsAwarded: null,
    ),
  ],
  milestoneHistory: [
    ReferralMilestoneHistory(
      id: 'm1',
      description: 'First Recruit',
      coins: 250,
      date: DateTime.utc(2026, 10, 10),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  ReferralOverview? overview,
  double width = 375,
  Future<void> Function(String)? share,
  Future<void> Function(String)? whatsapp,
  Future<void> Function(String)? copy,
  bool signedOut = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        referralOverviewProvider.overrideWith(
          (ref) async => signedOut ? null : overview ?? _overview,
        ),
        referralShareProvider.overrideWithValue(share ?? (_) async {}),
        referralWhatsAppProvider.overrideWithValue(whatsapp ?? (_) async {}),
        referralCopyProvider.overrideWithValue(copy ?? (_) async {}),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReferralScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows link, conversions, invited statuses and milestone history',
    (tester) async {
      String? shared;
      String? whatsapp;
      String? copied;
      await _pump(
        tester,
        locale: const Locale('en'),
        share: (value) async => shared = value,
        whatsapp: (value) async => whatsapp = value,
        copy: (value) async => copied = value,
      );
      expect(find.text('Friend One'), findsOneWidget);
      expect(find.textContaining('signup?ref=owner'), findsOneWidget);
      await tester.tap(find.byKey(const Key('referral-copy')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, contains('signup?ref=owner'));
      await tester.tap(find.byKey(const Key('referral-share')));
      await tester.pump();
      expect(shared, contains('signup?ref=owner'));
      await tester.tap(find.byKey(const Key('referral-whatsapp')));
      await tester.pump();
      expect(whatsapp, contains('signup?ref=owner'));
      await tester.scrollUntilVisible(
        find.text('Friend Two'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Friend Two'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Milestone history'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Milestone history'), findsOneWidget);
    },
  );

  testWidgets('shows empty and completed-milestone states', (tester) async {
    await _pump(
      tester,
      locale: const Locale('en'),
      overview: ReferralOverview(
        username: 'owner',
        shareUrl: 'https://sentinelxesports.com.ng/signup?ref=owner',
        totalReferrals: 0,
        convertedCount: 50,
        totalCoinsEarned: 5000,
        nextMilestone: null,
        invited: const [],
        milestoneHistory: const [],
      ),
    );
    expect(find.textContaining('No referrals yet'), findsOneWidget);
    expect(find.text('All milestones reached'), findsOneWidget);
  });

  testWidgets('signed out visitors see a login action', (tester) async {
    await _pump(tester, locale: const Locale('en'), signedOut: true);
    expect(find.text('Log in to see your referrals.'), findsOneWidget);
    expect(find.byKey(const Key('referral-login')), findsOneWidget);
  });

  for (final locale in ['fr', 'pcm']) {
    testWidgets('$locale fits at 320 px', (tester) async {
      await _pump(tester, locale: Locale(locale), width: 320);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Friend Two'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
