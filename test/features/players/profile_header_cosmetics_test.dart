import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/players/profile_sections.dart';
import 'package:sentinelx_mobile/shared/cosmetics/cosmetic_style.dart';

ProfileHeader _header({String? colour, String? theme}) => ProfileHeader(
      id: 'p1', username: 'ada', displayName: 'Ada Obi', avatarUrl: null, frameUrl: null,
      profileTheme: theme, usernameColour: colour, country: null, bio: null, createdAt: null,
      sxScore: 100, sentinelTier: null, membershipTier: 'recruit', xp: 0,
    );

Future<void> _pump(WidgetTester tester, ProfileHeader header, {double width = 375}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProfileHeaderSection(
        player: header, siteUrl: 'https://s.test', followerCount: 3, followingCount: 4, onFollowers: () {}, onFollowing: () {},
      ),
    ),
  ));
}

Color? _nameColour(WidgetTester tester) => tester.widget<Text>(find.text('Ada Obi')).style?.color;

void main() {
  testWidgets('a username colour paints the display name', (tester) async {
    await _pump(tester, _header(colour: 'username_gold'));
    expect(_nameColour(tester), CosmeticStyle.usernameColour('username_gold'));
  });

  testWidgets('a profile theme sits behind the header', (tester) async {
    await _pump(tester, _header(theme: 'theme_lagos_skyline'));
    final themed = find.byKey(const Key('profile-theme'));
    expect(themed, findsOneWidget);
    expect(tester.widget<DecoratedBox>(themed).decoration, CosmeticStyle.profileTheme('theme_lagos_skyline'));
  });

  testWidgets('with nothing equipped the header is exactly as before: default name colour, no theme box', (tester) async {
    await _pump(tester, _header());
    expect(_nameColour(tester), Theme.of(tester.element(find.text('Ada Obi'))).textTheme.titleLarge?.color);
    expect(find.byKey(const Key('profile-theme')), findsNothing);
  });

  testWidgets('unknown slugs behave like nothing equipped, never an error', (tester) async {
    await _pump(tester, _header(colour: 'username_pink', theme: 'theme_future'));
    expect(find.byKey(const Key('profile-theme')), findsNothing);
    expect(tester.takeException(), isNull);
    expect(_nameColour(tester), Theme.of(tester.element(find.text('Ada Obi'))).textTheme.titleLarge?.color);
  });

  testWidgets('a themed, coloured header fits at 320px', (tester) async {
    await _pump(tester, _header(colour: 'username_teal', theme: 'theme_neon_grid'), width: 320);
    expect(tester.takeException(), isNull);
  });
}
