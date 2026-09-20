import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/bracket_screen.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';

import '../fakes/fake_tournaments_repository.dart';
import '../support/pump_app.dart';

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

    await pumpWithRepo(tester, repository, const BracketScreen(tournamentId: 't1'));

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

    await pumpWithRepo(tester, repository, const BracketScreen(tournamentId: 't1'));
    await tester.pumpAndSettle();

    expect(find.text('TBD'), findsNWidgets(2));
    expect(find.textContaining(' - '), findsNothing);
  });

  testWidgets('shows an empty state when the tournament has no matches yet', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: const {});

    await pumpWithRepo(tester, repository, const BracketScreen(tournamentId: 't1'));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(bracketError: Exception('network down'));

    await pumpWithRepo(tester, repository, const BracketScreen(tournamentId: 't1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load bracket'), findsOneWidget);
  });

  testWidgets(
    'a large group-stage round scrolls vertically without overflowing',
    (tester) async {
      // Live tournaments have had group stages with up to 60 matches in a
      // single round. Use a realistic count (well above the 1-3 matches the
      // other tests use) so a regression in round-column scrolling shows up.
      const matchCount = 24;
      final groupMatches = [
        for (var i = 0; i < matchCount; i++)
          _match(
            id: 'group-$i',
            round: 'group',
            a: 'Team A$i',
            b: 'Team B$i',
          ),
      ];
      final repository = FakeTournamentsRepository(matchesByTournament: {
        't1': [
          ...groupMatches,
          _match(id: 'final', round: 'final', a: 'Finalist A', b: 'Finalist B'),
        ],
      });

      // A bounded, typical phone-sized viewport - the overflow only manifests
      // when the round column has a real height constraint to overflow past.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpWithRepo(tester, repository, const BracketScreen(tournamentId: 't1'));
      await tester.pumpAndSettle();

      // No RenderFlex overflow (or any other) exception was thrown while
      // laying out the long group-stage column.
      expect(tester.takeException(), isNull);

      // SingleChildScrollView builds its whole child eagerly, so the last
      // match's Text exists in the tree even when scrolled out of view -
      // check its actual screen position instead of mere existence. Before
      // scrolling it should sit below the visible viewport.
      final lastMatchFinder = find.text('Team A${matchCount - 1}');
      expect(lastMatchFinder, findsOneWidget);
      final beforeScrollY = tester.getTopLeft(lastMatchFinder).dy;
      expect(beforeScrollY, greaterThan(800));

      // Scrolling the group round's own vertical Scrollable (the nearest
      // Scrollable ancestor of one of its match cards) down makes it
      // actually reachable, moving it into the visible viewport.
      final groupColumnScrollable = find
          .ancestor(of: find.text('Team A0'), matching: find.byType(Scrollable))
          .first;
      await tester.drag(groupColumnScrollable, const Offset(0, -5000));
      await tester.pumpAndSettle();

      final afterScrollY = tester.getTopLeft(lastMatchFinder).dy;
      expect(afterScrollY, greaterThanOrEqualTo(0));
      expect(afterScrollY, lessThan(800));
      expect(tester.takeException(), isNull);
    },
  );
}
