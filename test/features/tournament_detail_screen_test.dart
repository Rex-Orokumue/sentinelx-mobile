import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/tournament_detail_screen.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

import '../fakes/fake_tournaments_repository.dart';
import '../support/pump_app.dart';

Tournament _detailTournament() {
  return Tournament(
    id: 't1',
    title: 'FC Mobile Premier League — Season 2',
    slug: 'fc-mobile-premier-league-season-2',
    description: 'The second season of the FC Mobile Premier League.',
    bannerUrl: null,
    cardImageUrl: null,
    status: 'active',
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 50000,
    prizeSecond: 20000,
    prizeThird: 10000,
    registrationFee: 500,
    maxPlayers: 32,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: DateTime.parse('2026-09-11T00:00:00+00:00'),
    tournamentEnd: null,
    rules: 'Standard rules apply.',
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('shows tournament details once loaded', (tester) async {
    final repository = FakeTournamentsRepository(tournamentById: _detailTournament());

    await pumpWithRepo(tester, repository, TournamentDetailScreen(tournamentId: 't1', onViewBracket: () {}));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League — Season 2'), findsOneWidget);
    expect(find.textContaining('EA FC Mobile'), findsOneWidget);
    expect(find.textContaining('50000'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(tournamentError: Exception('not found'));

    await pumpWithRepo(tester, repository, TournamentDetailScreen(tournamentId: 'missing', onViewBracket: () {}));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load tournament'), findsOneWidget);
  });

  testWidgets('tapping View Bracket invokes onViewBracket', (tester) async {
    final repository = FakeTournamentsRepository(tournamentById: _detailTournament());
    var tapped = false;

    await pumpWithRepo(tester, repository, TournamentDetailScreen(tournamentId: 't1', onViewBracket: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
