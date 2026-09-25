import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/player_profile_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/players_fixtures.dart';

MeResponse _me(String id) => MeResponse(id: id, email: null, roles: const [], isStaff: false, isAdmin: false, profile: null);

Widget _app(FakePlayersRepository repo, {String? meId, VoidCallback? onLogIn, String username = 'ada'}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => meId == null ? null : _me(meId)),
        followRetryDelayProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerProfileScreen(
          username: username,
          onLogIn: onLogIn ?? () {},
          onOpenFollowers: (_) {},
          onOpenFollowing: (_) {},
        ),
      ),
    );

void main() {
  // 375 x 812 logical px, like the target devices, so the overflow assertions mean something.
  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('renders header, stats, titles, matches, posts and shows the mixed achievements without overflow', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Plays DLS.'), findsOneWidget);
    expect(find.text('Masters Sept'), findsWidgets);
    // The list is lazy: rows below the fold only exist once scrolled to.
    await tester.scrollUntilVisible(find.byKey(const Key('match-row-m1')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('match-row-m1')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('GG everyone'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('GG everyone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked achievements are anonymous tiles: count only, no names', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(totalAchievements: 5, unlockedAchievements: 2);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('locked-tile-0')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('locked-tile-0')), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-2')), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-3')), findsNothing); // 5 total - 2 unlocked = 3
    expect(find.text('2/5 unlocked'), findsOneWidget);
    expect(find.byKey(const Key('achievement-a0')), findsOneWidget);
  });

  testWidgets('a player with no achievements, no rank, no bio and no activity renders without a crash', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()
      ..profileData = profileJson(totalAchievements: 0, unlockedAchievements: 0, rank: null, totalRanked: null, bio: null, withActivity: false);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('No titles yet.'), findsOneWidget);
    expect(find.text('No matches yet.'), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very long display name and bio do not overflow at 375px', (tester) async {
    await phone(tester);
    final data = profileJson(bio: List.filled(300, 'word').join(' '));
    (data['player'] as Map<String, dynamic>)['displayName'] = 'An extremely long display name that keeps going and going and going';
    final repo = FakePlayersRepository()..profileData = data;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('404 shows the neutral not-found state and no follow button', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileError = apiError(404, 'not_found');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-not-found')), findsOneWidget);
    expect(find.byKey(const Key('follow-button')), findsNothing);
  });

  testWidgets('signed out: no /me/follows call, and tapping Follow opens login instead of flipping state', (tester) async {
    await phone(tester);
    var loginOpened = 0;
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo, onLogIn: () => loginOpened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    expect(loginOpened, 1);
    expect(repo.myFollowsCalls, 0);
    expect(repo.followCalls, isEmpty);
  });

  testWidgets('own profile has no follow button', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(id: 'me1');
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('follow-button')), findsNothing);
  });

  testWidgets('follow: optimistic flip, correct PUT, and the follower count moves by one despite the cached body', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(followerCount: 10);
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('10 followers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('11 followers'), findsOneWidget);
    expect(repo.followCalls.single.username, 'ada');
  });

  testWidgets('blocked follow rolls the button back and shows the blocked message', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..followErrors.add(apiError(403, 'follow_blocked'));
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text("You can't follow this player."), findsOneWidget);
    expect(find.text('10 followers'), findsOneWidget);
  });

  testWidgets('a session-expired follow (401) sends the user to login', (tester) async {
    await phone(tester);
    var loginOpened = 0;
    final repo = FakePlayersRepository()..followErrors.add(apiError(401, 'unauthorized'));
    await tester.pumpWidget(_app(repo, meId: 'me1', onLogIn: () => loginOpened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(loginOpened, 1);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('already following: shows Following, and "Follows you" when they follow back; unfollow flips it', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..sets = const FollowSets(followingIds: {'p1'}, followerIds: {'p1'});
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    expect(find.byKey(const Key('follows-you-chip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(repo.unfollowCalls, ['ada']);
  });
}
