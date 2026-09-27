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

class RankingsCacheNotifier extends Notifier<RankingsPage?> {
  @override
  RankingsPage? build() => null;
  void store(RankingsPage page) => state = page;
}

final rankingsCacheProvider =
    NotifierProvider<RankingsCacheNotifier, RankingsPage?>(
      RankingsCacheNotifier.new,
    );
final rankingsProvider = FutureProvider.autoDispose<RankingsPage>((ref) async {
  final page = await ref
      .watch(rankingsRepositoryProvider)
      .fetch(ref.watch(rankingsQueryProvider));
  ref.read(rankingsCacheProvider.notifier).store(page);
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
