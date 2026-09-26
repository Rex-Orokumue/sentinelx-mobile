import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/bracket/bracket_screen.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/match_fixtures.dart';
import '../../support/pump_compete.dart';

class _Env {
  final repo = FakeMatchRepository();
  final reads = FakeMatchReads();
  final matchTaps = <String>[];
  final stageTaps = <StageInfo>[];
}

Map<String, dynamic> _emptyFixtures() => {
      'live': <Map<String, dynamic>>[],
      'upcoming': <Map<String, dynamic>>[],
      'completed': <Map<String, dynamic>>[],
      'disputedOrCancelled': <Map<String, dynamic>>[],
    };

Future<_Env> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? json,
  List<StageInfo> stages = const [],
  bool stagesFail = false,
  bool bracketFails = false,
}) async {
  final env = _Env();
  env.repo.bracketView = BracketView.fromJson(json ?? bracketJson());
  if (bracketFails) env.repo.bracketError = Exception('boom');
  env.reads.stages = stages;
  env.reads.failStages = stagesFail;
  await pumpCompete(
    tester,
    BracketScreen(tournamentId: 't1', onMatchTap: env.matchTaps.add, onStageTap: env.stageTaps.add),
    overrides: [
      matchRepositoryProvider.overrideWithValue(env.repo),
      matchReadsRepositoryProvider.overrideWithValue(env.reads),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

Future<void> _openTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

const _stage = StageInfo(id: 's1', seq: 1, name: 'Qualifier stage', status: 'active');

void main() {
  testWidgets('groups-only view shows Groups and Fixtures, hides Knockout', (tester) async {
    await _pump(tester, json: bracketJson(withKnockout: false));
    expect(find.byKey(const Key('tab-groups')), findsOneWidget);
    expect(find.byKey(const Key('tab-fixtures')), findsOneWidget);
    expect(find.byKey(const Key('tab-knockout')), findsNothing);
    expect(find.text('Group A'), findsOneWidget);
  });

  testWidgets('knockout-only view hides Groups', (tester) async {
    await _pump(tester, json: bracketJson(groups: 0));
    expect(find.byKey(const Key('tab-groups')), findsNothing);
    expect(find.byKey(const Key('tab-knockout')), findsOneWidget);
  });

  testWidgets('no draw yet: a single message and no TabBar', (tester) async {
    final json = bracketJson(groups: 0, withKnockout: false)..['fixtures'] = _emptyFixtures();
    await _pump(tester, json: json);
    expect(find.text("The draw hasn't been made yet."), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('champion banner, with and without third place; none when champion is null', (tester) async {
    await _pump(tester, json: bracketJson(champion: {'id': 'p1', 'name': 'Ada'}));
    expect(find.byKey(const Key('champion-banner')), findsOneWidget);
    expect(find.text('Champion'), findsOneWidget);
    expect(find.text('Ada'), findsWidgets);
    expect(find.textContaining('Third place'), findsNothing);

    final withThird = bracketJson(champion: {'id': 'p1', 'name': 'Ada'})..['thirdPlace'] = {'id': 'p3', 'name': 'Chi'};
    await _pump(tester, json: withThird);
    expect(find.text('Third place: Chi'), findsOneWidget);

    await _pump(tester, json: bracketJson());
    expect(find.byKey(const Key('champion-banner')), findsNothing);
  });

  testWidgets('group table marks advancing rows with a semantic label', (tester) async {
    await _pump(tester, json: bracketJson());
    expect(find.byKey(const Key('advancing-p1')), findsOneWidget);
    expect(find.byKey(const Key('advancing-p2')), findsNothing);
    expect(find.text('Pts'), findsOneWidget);
    expect(find.text('FC Ada'), findsNothing); // clubs are not part of the table
  });

  testWidgets('a fixture with null scores shows the schedule, not "null – null"', (tester) async {
    final json = bracketJson()
      ..['fixtures'] = (_emptyFixtures()
        ..['upcoming'] = [fixtureJson(id: 'u1', scheduledAt: null)]
        ..['live'] = [fixtureJson(id: 'l1', status: 'live', scheduledAt: null)]);
    await _pump(tester, json: json);
    await _openTab(tester, 'tab-fixtures');
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('To be announced'), findsNWidgets(2));
  });

  testWidgets('a completed fixture shows its score', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'tab-fixtures');
    expect(find.text('2 – 1'), findsOneWidget);
  });

  testWidgets('a bye row shows Bye and is not tappable; a normal row calls onMatchTap', (tester) async {
    final json = bracketJson()
      ..['fixtures'] = (_emptyFixtures()
        ..['upcoming'] = [fixtureJson(id: 'bye1', status: 'bye'), fixtureJson(id: 'real1')]);
    final env = await _pump(tester, json: json);
    await _openTab(tester, 'tab-fixtures');
    expect(find.text('Bye'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fixture-bye1')));
    expect(env.matchTaps, isEmpty);
    await tester.tap(find.byKey(const Key('fixture-real1')));
    expect(env.matchTaps, ['real1']);
  });

  testWidgets('empty fixture buckets are omitted', (tester) async {
    await _pump(tester);
    await _openTab(tester, 'tab-fixtures');
    expect(find.byKey(const Key('section-live')), findsOneWidget);
    expect(find.byKey(const Key('section-upcoming')), findsOneWidget);
    expect(find.byKey(const Key('section-completed')), findsOneWidget);
    expect(find.byKey(const Key('section-disputed')), findsNothing);
  });

  testWidgets('knockout: API labels as headings, projected rounds and third-place match', (tester) async {
    final json = bracketJson()..['thirdPlaceMatch'] = fixtureJson(id: 'tp1', round: 'third_place');
    await _pump(tester, json: json);
    await _openTab(tester, 'tab-knockout');
    expect(find.text('Semi-finals'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('1 matches to come'), findsOneWidget);
    expect(find.text('Third place'), findsOneWidget);
    expect(find.byKey(const Key('fixture-tp1')), findsOneWidget);
  });

  testWidgets('60-char names and 5 knockout rounds do not overflow at 375px', (tester) async {
    final long = 'N' * 60;
    final rounds = [
      for (var i = 0; i < 5; i++)
        {
          'round': 'r$i',
          'label': 'Round label $i',
          'matches': [
            fixtureJson(id: 'k$i', round: 'r$i', playerA: nameRefJson('a$i', long), playerB: nameRefJson('b$i', long)),
          ],
        },
    ];
    final json = bracketJson()
      ..['rounds'] = rounds
      ..['standings'] = [
        {
          'groupId': 'g',
          'groupName': 'G' * 60,
          'rows': [standingRowJson(name: long, clubName: long)],
        },
      ];
    await _pump(tester, json: json);
    expect(tester.takeException(), isNull);
    await _openTab(tester, 'tab-fixtures');
    expect(tester.takeException(), isNull);
    await _openTab(tester, 'tab-knockout');
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure shows friendly copy, never the exception', (tester) async {
    await _pump(tester, bracketFails: true);
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a stage row calls onStageTap; a stages failure hides only that section', (tester) async {
    final env = await _pump(tester, stages: [_stage]);
    expect(find.text('Stages'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stage-s1')));
    expect(env.stageTaps.single.id, 's1');

    await _pump(tester, stagesFail: true);
    expect(find.text('Stages'), findsNothing);
    expect(find.byKey(const Key('tab-fixtures')), findsOneWidget); // the rest of the page still renders
  });

  testWidgets('a points-race tournament with no draw still lists its stages', (tester) async {
    final json = bracketJson(groups: 0, withKnockout: false)..['fixtures'] = _emptyFixtures();
    await _pump(tester, json: json, stages: [_stage]);
    expect(find.text("The draw hasn't been made yet."), findsOneWidget);
    expect(find.byKey(const Key('stage-s1')), findsOneWidget);
  });
}
