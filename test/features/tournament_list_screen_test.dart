import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/tournament_list_screen.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

import '../fakes/fake_tournaments_repository.dart';
import '../support/pump_app.dart';

Tournament _tournament({required String id, required String title, required String status}) {
  return Tournament(
    id: id,
    title: title,
    slug: title.toLowerCase().replaceAll(' ', '-'),
    description: null,
    bannerUrl: null,
    cardImageUrl: null,
    status: status,
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
  testWidgets('shows a loading indicator, then the fetched tournaments', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: [
      _tournament(id: 't1', title: 'FC Mobile Premier League', status: 'active'),
      _tournament(id: 't2', title: 'DLS Community Cup III', status: 'completed'),
    ]);

    await pumpWithRepo(tester, repository, TournamentListScreen(onTournamentTap: (_) {}));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('FC Mobile Premier League'), findsOneWidget);
    expect(find.text('DLS Community Cup III'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no tournaments', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);

    await pumpWithRepo(tester, repository, TournamentListScreen(onTournamentTap: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('No tournaments yet.'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(tournamentsError: Exception('network down'));

    await pumpWithRepo(tester, repository, TournamentListScreen(onTournamentTap: (_) {}));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load tournaments'), findsOneWidget);
  });

  testWidgets('tapping a tournament invokes onTournamentTap with that tournament', (tester) async {
    final tournament = _tournament(id: 't1', title: 'FC Mobile Premier League', status: 'active');
    final repository = FakeTournamentsRepository(tournaments: [tournament]);
    Tournament? tapped;

    await pumpWithRepo(tester, repository, TournamentListScreen(onTournamentTap: (t) => tapped = t));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pump();

    expect(tapped, tournament);
  });
}
