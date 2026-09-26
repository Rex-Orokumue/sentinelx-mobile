import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../support/compete_fixtures.dart';

List<CompeteTournament> _many(int n) =>
    List.generate(n, (i) => CompeteTournament.fromJson(tournamentRow(id: 't$i', title: 'T$i')));

ProviderContainer _container(FakeCompeteReads fake) {
  final c = ProviderContainer(retry: (_, _) => null, overrides: [competeReadsRepositoryProvider.overrideWithValue(fake)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('loads page 1, then load more appends and stops on a short page', () async {
    final fake = FakeCompeteReads(tournaments: _many(kTournamentPageSize + 3));
    final c = _container(fake);
    final first = await c.read(tournamentListProvider.future);
    expect(first.items.length, kTournamentPageSize);
    expect(first.hasMore, isTrue);
    await c.read(tournamentListProvider.notifier).loadMore();
    final s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize + 3);
    expect(s.hasMore, isFalse);
    await c.read(tournamentListProvider.notifier).loadMore(); // no-op, no third request
    expect(fake.pagesRequested, [1, 2]);
  });

  test('a failed load-more keeps the items, flags a retry and does not loop', () async {
    final fake = FakeCompeteReads(tournaments: _many(kTournamentPageSize + 3), failNextPage: true);
    final c = _container(fake);
    await c.read(tournamentListProvider.future);
    await c.read(tournamentListProvider.notifier).loadMore();
    var s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize);
    expect(s.loadMoreFailed, isTrue);
    expect(fake.pagesRequested, [1, 2]);
    await c.read(tournamentListProvider.notifier).loadMore(); // explicit retry succeeds
    s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize + 3);
    expect(s.loadMoreFailed, isFalse);
  });

  test('changing the tab or game reloads from page 1', () async {
    final fake = FakeCompeteReads(tournaments: _many(2));
    final c = _container(fake);
    await c.read(tournamentListProvider.future);
    c.read(tournamentTabProvider.notifier).select(TournamentTab.live);
    await c.read(tournamentListProvider.future);
    c.read(tournamentGameFilterProvider.notifier).select('fc-mobile');
    await c.read(tournamentListProvider.future);
    expect(fake.tabsRequested, [TournamentTab.all, TournamentTab.live, TournamentTab.live]);
    expect(fake.gamesRequested, [null, null, 'fc-mobile']);
    expect(fake.pagesRequested, [1, 1, 1]);
  });

  test('looksLikeUuid distinguishes ids from slugs', () {
    expect(looksLikeUuid('3f2b8c1e-4d5a-4e6f-9a7b-1c2d3e4f5a6b'), isTrue);
    expect(looksLikeUuid('fc-mobile-cup'), isFalse);
    expect(looksLikeUuid(''), isFalse);
  });
}
