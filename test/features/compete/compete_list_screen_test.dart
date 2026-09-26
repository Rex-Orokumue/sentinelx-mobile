import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_list_screen.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../support/compete_fixtures.dart';
import '../../support/pump_compete.dart';

CompeteTournament _t(int i, {int fee = 500, Object? games = const {'name': 'FC Mobile', 'slug': 'fc-mobile'}, String? title}) =>
    CompeteTournament.fromJson(tournamentRow(id: 't$i', title: title ?? 'Cup $i', registrationFee: fee, games: games));

final _listScrollable = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));

Future<List<CompeteTournament>> _tapped(WidgetTester tester, FakeCompeteReads fake) async {
  final tapped = <CompeteTournament>[];
  await pumpCompete(
    tester,
    CompeteListScreen(onTournamentTap: tapped.add),
    overrides: [competeReadsRepositoryProvider.overrideWithValue(fake)],
  );
  await tester.pumpAndSettle();
  return tapped;
}

void main() {
  testWidgets('rows show title, game, prize and fee; a zero fee reads Free', (tester) async {
    await _tapped(tester, FakeCompeteReads(tournaments: [_t(1), _t(2, fee: 0)]));
    expect(find.text('Cup 1'), findsOneWidget);
    expect(find.text('FC Mobile'), findsNWidgets(2));
    expect(find.textContaining('₦8000'), findsNWidgets(2));
    expect(find.textContaining('₦500'), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
    expect(find.text('Registration open'), findsNWidgets(2));
  });

  testWidgets('a tournament whose games join is null still renders', (tester) async {
    await _tapped(tester, FakeCompeteReads(tournaments: [_t(1, games: null)]));
    expect(find.text('Cup 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row reports that tournament', (tester) async {
    final fake = FakeCompeteReads(tournaments: [_t(1), _t(2)]);
    final tapped = await _tapped(tester, fake);
    await tester.tap(find.byKey(const Key('tournament-tile-t2')));
    expect(tapped.single.id, 't2');
  });

  testWidgets('the tab chips and game chips reload with the chosen filters', (tester) async {
    final fake = FakeCompeteReads(
      tournaments: [_t(1)],
      games: const [GameSummary(id: 'g1', name: 'FC Mobile', slug: 'fc-mobile', iconUrl: null)],
    );
    await _tapped(tester, fake);
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(fake.tabsRequested.last, TournamentTab.live);
    await tester.tap(find.byKey(const Key('game-chip-fc-mobile')));
    await tester.pumpAndSettle();
    expect(fake.gamesRequested.last, 'fc-mobile');
    expect(fake.pagesRequested.last, 1);
  });

  testWidgets('load more appears after a full page and appends page 2', (tester) async {
    final fake = FakeCompeteReads(tournaments: [for (var i = 0; i < kTournamentPageSize + 2; i++) _t(i)]);
    await _tapped(tester, fake);
    await tester.scrollUntilVisible(find.text('Load more'), 300, scrollable: _listScrollable);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(fake.pagesRequested, [1, 2]);
    await tester.scrollUntilVisible(find.text('Cup ${kTournamentPageSize + 1}'), 300, scrollable: _listScrollable);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a failed load-more keeps the rows and offers Try again', (tester) async {
    final fake = FakeCompeteReads(tournaments: [for (var i = 0; i < kTournamentPageSize + 2; i++) _t(i)], failNextPage: true);
    await _tapped(tester, fake);
    await tester.scrollUntilVisible(find.text('Load more'), 300, scrollable: _listScrollable);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    expect(fake.pagesRequested, [1, 2]);
  });

  testWidgets('empty list says so', (tester) async {
    await _tapped(tester, FakeCompeteReads());
    expect(find.text('No tournaments here yet.'), findsOneWidget);
  });

  testWidgets('a load failure shows friendly copy, never the exception', (tester) async {
    await _tapped(tester, FakeCompeteReads(failAll: true));
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('pull to refresh re-fetches page 1', (tester) async {
    final fake = FakeCompeteReads(tournaments: [_t(1)]);
    await _tapped(tester, fake);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(fake.pagesRequested.length, greaterThanOrEqualTo(2));
    expect(fake.pagesRequested.every((p) => p == 1), isTrue);
  });

  testWidgets('a 60-character title fits 375px without overflow', (tester) async {
    await _tapped(tester, FakeCompeteReads(tournaments: [_t(1, title: 'T' * 60)]));
    expect(tester.takeException(), isNull);
  });
}
