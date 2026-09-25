import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/follow_list_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/players_fixtures.dart';

Widget _app(FakePlayersRepository repo, {FollowListKind kind = FollowListKind.followers, bool signedIn = false, void Function(String)? onTap}) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FollowListScreen(username: 'ada', kind: kind, onPlayerTap: onTap ?? (_) {}),
      ),
    );

void main() {
  testWidgets('a tombstone entry renders "Deleted player" and is not tappable; a live entry navigates', (tester) async {
    final repo = FakePlayersRepository()
      ..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola')), FollowEntry.fromJson(followEntryJson('u2', null))];
    String? tapped;
    await tester.pumpWidget(_app(repo, onTap: (u) => tapped = u));
    await tester.pumpAndSettle();
    expect(find.text('Deleted player'), findsOneWidget);
    await tester.tap(find.text('Deleted player'));
    expect(tapped, isNull);
    await tester.tap(find.text('BOLA'));
    expect(tapped, 'bola');
  });

  testWidgets('signed in: Following / Follows you chips come from /me/follows; signed out: no chips and no /me call', (tester) async {
    final repo = FakePlayersRepository()
      ..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola')), FollowEntry.fromJson(followEntryJson('me1', 'me_user'))]
      ..sets = const FollowSets(followingIds: {'u1', 'me1'}, followerIds: {'u1'});
    await tester.pumpWidget(_app(repo, signedIn: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chip-following-u1')), findsOneWidget);
    expect(find.byKey(const Key('chip-follows-you-u1')), findsOneWidget);
    expect(find.byKey(const Key('chip-following-me1')), findsNothing); // never for the viewer's own row

    final anon = FakePlayersRepository()..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola'))];
    await tester.pumpWidget(const SizedBox()); // drop the signed-in scope so providers start fresh
    await tester.pumpWidget(_app(anon));
    await tester.pumpAndSettle();
    expect(anon.myFollowsCalls, 0);
    expect(find.byKey(const Key('chip-following-u1')), findsNothing);
  });

  testWidgets('empty followers vs empty following show their own messages', (tester) async {
    await tester.pumpWidget(_app(FakePlayersRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No followers yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(FakePlayersRepository(), kind: FollowListKind.following));
    await tester.pumpAndSettle();
    expect(find.text('Not following anyone yet.'), findsOneWidget);
  });
}
