import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/bracket/stage_standings_screen.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/pump_compete.dart';

const _stage = StageInfo(id: 's1', seq: 1, name: 'Qualifier stage', status: 'active');

PointsStandingRow _row(String id, String name, int rank, {bool advancing = false, List<String> tie = const [], int points = 30, int kills = 5}) =>
    PointsStandingRow(
      entrantId: id,
      displayName: name,
      played: 2,
      totalPoints: points,
      totalKills: kills,
      bestPlacement: 1,
      lastRoundPlacement: 2,
      rank: rank,
      advancing: advancing,
      unresolvedTieWith: tie,
    );

Future<FakeMatchRepository> _pump(WidgetTester tester, {List<PointsStandingRow> rows = const [], Object? error}) async {
  final repo = FakeMatchRepository()
    ..stageRows = rows
    ..stageError = error;
  await pumpCompete(
    tester,
    const StageStandingsScreen(tournamentId: 't1', stage: _stage),
    overrides: [matchRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('renders rank, name, points and kills', (tester) async {
    await _pump(tester, rows: [_row('e1', 'Ada', 1, points: 41, kills: 9), _row('e2', 'Bola', 2, points: 33, kills: 4)]);
    expect(find.text('Qualifier stage'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Bola'), findsOneWidget);
    expect(find.text('Kills'), findsOneWidget);
  });

  testWidgets('marks advancing entrants', (tester) async {
    await _pump(tester, rows: [_row('e1', 'Ada', 1, advancing: true), _row('e2', 'Bola', 2)]);
    expect(find.byKey(const Key('advancing-e1')), findsOneWidget);
    expect(find.byKey(const Key('advancing-e2')), findsNothing);
  });

  testWidgets('an unresolved tie shows the tie copy', (tester) async {
    await _pump(tester, rows: [_row('e1', 'Ada', 1, tie: ['e2']), _row('e2', 'Bola', 1, tie: ['e1'])]);
    expect(find.text('Tied — awaiting tiebreak'), findsNWidgets(2));
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester);
    expect(find.text("The draw hasn't been made yet."), findsOneWidget);
  });

  testWidgets('error state is friendly and has a retry that re-reads', (tester) async {
    final repo = await _pump(tester, error: Exception('boom'));
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    repo.stageError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.stageCalls, 2);
  });

  testWidgets('a 60-char name does not overflow', (tester) async {
    await _pump(tester, rows: [_row('e1', 'N' * 60, 1)]);
    expect(tester.takeException(), isNull);
  });
}
