import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/models/tournament.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_tournaments_repository.dart';
import '../support/pump_app.dart';

Tournament _tournament() {
  return const Tournament(
    id: 't1',
    title: 'FC Mobile Premier League',
    slug: 'fc-mobile-premier-league',
    description: null,
    bannerUrl: null,
    cardImageUrl: null,
    status: 'active',
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 10000,
    prizeSecond: null,
    prizeThird: null,
    registrationFee: 500,
    maxPlayers: 16,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: null,
    tournamentEnd: null,
    rules: null,
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('navigates list -> detail -> bracket and back', (tester) async {
    final repository = FakeTournamentsRepository(
      tournaments: [_tournament()],
      tournamentById: _tournament(),
      matchesByTournament: const {},
    );

    await pumpRouterWithRepo(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);
  });

  test('the /debug route exists only when debug tools are enabled', () {
    bool hasDebug(bool tools) => buildAppRouter(debugTools: tools)
        .configuration
        .routes
        .whereType<GoRoute>()
        .any((r) => r.path == '/debug');
    expect(hasDebug(false), isFalse);
    expect(hasDebug(true), isTrue);
  });
}
