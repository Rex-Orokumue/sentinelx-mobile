import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/providers.dart';
import 'rankings_repository.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>(
  (ref) => ApiRankingsRepository(ref.watch(apiClientProvider)),
);

class RankingsQueryNotifier extends Notifier<RankingsQuery> {
  @override
  RankingsQuery build() => const RankingsQuery();
  void setGame(String? v) =>
      state = state.copyWith(game: v, region: null, page: 1);
  void setRegion(String? v) => state = state.copyWith(region: v, page: 1);
  void setPage(int v) => state = state.copyWith(page: v);
  void setMetric(String v) => state = state.copyWith(metric: v, tabGame: null);
  void setTabGame(String? v) => state = state.copyWith(tabGame: v);
}

final rankingsQueryProvider =
    NotifierProvider.autoDispose<RankingsQueryNotifier, RankingsQuery>(
      RankingsQueryNotifier.new,
    );

RankingsQuery rankingsCacheKey(RankingsQuery query) => query.copyWith(page: 1);

// The filter domain (game/region/metric/tabGame) is small and finite, but
// cap the cache defensively so it can never grow unbounded across a long
// session.
const _rankingsCacheCap = 8;

class RankingsCacheNotifier
    extends Notifier<Map<RankingsQuery, RankingsPage>> {
  @override
  Map<RankingsQuery, RankingsPage> build() => {};
  void store(RankingsQuery query, RankingsPage page) {
    final next = {...state, rankingsCacheKey(query): page};
    if (next.length <= _rankingsCacheCap) {
      state = next;
      return;
    }
    // Insertion order is preserved by the map's spread above (re-storing an
    // existing key updates its value without moving it), so the oldest
    // untouched entries sit first and are evicted first.
    final trimmed = Map.of(next);
    while (trimmed.length > _rankingsCacheCap) {
      trimmed.remove(trimmed.keys.first);
    }
    state = trimmed;
  }
}

final rankingsCacheProvider =
    NotifierProvider<RankingsCacheNotifier, Map<RankingsQuery, RankingsPage>>(
      RankingsCacheNotifier.new,
    );
final rankingsProvider = FutureProvider.autoDispose<RankingsPage>((ref) async {
  final query = ref.watch(rankingsQueryProvider);
  final page = await ref
      .watch(rankingsRepositoryProvider)
      .fetch(query);
  ref.read(rankingsCacheProvider.notifier).store(query, page);
  return page;
});
final rankingsMeProvider = FutureProvider.autoDispose<RankingRow?>((ref) async {
  if (await ref.watch(meProvider.future) == null) return null;
  final scope = ref.watch(
    rankingsQueryProvider.select(
      (q) => (
        game: q.game,
        region: q.region,
        metric: q.metric,
        tabGame: q.tabGame,
      ),
    ),
  );
  return (await ref
          .watch(rankingsRepositoryProvider)
          .fetchMe(
            RankingsQuery(
              game: scope.game,
              region: scope.region,
              metric: scope.metric,
              tabGame: scope.tabGame,
            ),
          ))
      .row;
});
