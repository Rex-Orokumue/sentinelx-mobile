import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/players_directory_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';

PlayerListItem _p(String u, {String? name}) => PlayerListItem(
    username: u, displayName: name, avatarUrl: null, sxScore: 900, sentinelTier: null, membershipTier: 'recruit', equippedAvatarBorder: null);

MeResponse _me(String username) => MeResponse(
      id: 'me1', email: null, roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(username: username, displayName: null, avatarUrl: null, whatsappNumber: null, country: null, locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null),
    );

Widget _app(FakePlayersRepository repo, {MeResponse? me, void Function(String)? onTap}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => me),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayersDirectoryScreen(onPlayerTap: onTap ?? (_) {}),
      ),
    );

void main() {
  testWidgets('lists players and reports a tap with the username', (tester) async {
    final repo = FakePlayersRepository()..searchResults = [_p('ada', name: 'Ada'), _p('bola')];
    String? tapped;
    await tester.pumpWidget(_app(repo, onTap: (u) => tapped = u));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('bola'), findsOneWidget);
    await tester.tap(find.byKey(const Key('player-row-ada')));
    expect(tapped, 'ada');
  });

  testWidgets('typing is debounced: three quick edits produce one search with the final text', (tester) async {
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    repo.searches.clear();
    final field = find.byKey(const Key('players-search'));
    await tester.enterText(field, 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ad');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.searches, ['ada']);
  });

  testWidgets('the signed-in viewer is filtered out of the results (the API cannot exclude them)', (tester) async {
    final repo = FakePlayersRepository()..searchResults = [_p('me_user', name: 'Me'), _p('ada')];
    await tester.pumpWidget(_app(repo, me: _me('me_user')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-row-me_user')), findsNothing);
    expect(find.byKey(const Key('player-row-ada')), findsOneWidget);
  });

  testWidgets('empty result shows the empty state', (tester) async {
    await tester.pumpWidget(_app(FakePlayersRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No players found.'), findsOneWidget);
  });

  testWidgets('a failed search shows a tappable retry, not a stack trace', (tester) async {
    final repo = _ThrowingRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load. Tap to retry."), findsOneWidget);
  });
}

class _ThrowingRepo extends FakePlayersRepository {
  @override
  Future<List<PlayerListItem>> search(String q) => throw apiError(500, 'internal');
}
