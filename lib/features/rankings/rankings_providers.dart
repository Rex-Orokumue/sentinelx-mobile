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

RankingsQuery _cacheKey(RankingsQuery query) => query.copyWith(page: 1);

class RankingsCacheNotifier
    extends Notifier<Map<RankingsQuery, RankingsPage>> {
  @override
  Map<RankingsQuery, RankingsPage> build() => {};
  void store(RankingsQuery query, RankingsPage page) =>
      state = {...state, _cacheKey(query): page};
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
