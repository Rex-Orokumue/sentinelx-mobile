import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/bracket_screen.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';

import '../fakes/fake_tournaments_repository.dart';

BracketMatch _match({
  required String id,
  required String round,
  String a = 'Player A',
  String b = 'Player B',
  int? scoreA,
  int? scoreB,
}) {
  return BracketMatch(
    id: id,
    tournamentId: 't1',
    round: round,
    status: scoreA == null ? 'scheduled' : 'completed',
    scoreA: scoreA,
    scoreB: scoreB,
    scheduledAt: null,
    completedAt: null,
    participantALabel: a,
    participantBLabel: b,
  );
}

void main() {
  testWidgets('groups matches under round headers, in bracket order', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: {
      't1': [
        _match(id: 'm1', round: 'final', a: 'Shadow Striker', b: 'Goal Machine', scoreA: 3, scoreB: 1),
        _match(id: 'm2', round: 'group', a: 'Team Alpha', b: 'Team Beta', scoreA: 2, scoreB: 2),
        _match(id: 'm3', round: 'semi_final', a: 'Shadow Striker', b: 'Iron Wall', scoreA: 4, scoreB: 0),
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Group Stage'), findsOneWidget);
    expect(find.text('Semifinal'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Shadow Striker'), findsNWidgets(2));
    expect(find.text('3 - 1'), findsOneWidget);

    final groupHeaderCenter = tester.getCenter(find.text('Group Stage'));
    final finalHeaderCenter = tester.getCenter(find.text('Final'));
    expect(groupHeaderCenter.dx, lessThan(finalHeaderCenter.dx));
  });

  testWidgets('shows TBD participants without a score for unscheduled matches', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: {
      't1': [
        BracketMatch(
          id: 'm1',
          tournamentId: 't1',
          round: 'quarter_final',
          status: 'scheduled',
          scoreA: null,
          scoreB: null,
          scheduledAt: null,
          completedAt: null,
          participantALabel: 'TBD',
          participantBLabel: 'TBD',
        ),
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TBD'), findsNWidgets(2));
    expect(find.textContaining(' - '), findsNothing);
  });

  testWidgets('shows an empty state when the tournament has no matches yet', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: const {});

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(bracketError: Exception('network down'));

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load bracket'), findsOneWidget);
  });
}
