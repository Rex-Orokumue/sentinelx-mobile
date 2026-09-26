import '../../core/api/api_client.dart';
import '../../core/api/progress_models.dart';

const _keep = Object();

class RankingsQuery {
  const RankingsQuery({
    this.game,
    this.region,
    this.page = 1,
    this.metric,
    this.tabGame,
  });
  final String? game, region, metric, tabGame;
  final int page;
  RankingsQuery copyWith({
    Object? game = _keep,
    Object? region = _keep,
    int? page,
    Object? metric = _keep,
    Object? tabGame = _keep,
  }) => RankingsQuery(
    game: identical(game, _keep) ? this.game : game as String?,
    region: identical(region, _keep) ? this.region : region as String?,
    page: page ?? this.page,
    metric: identical(metric, _keep) ? this.metric : metric as String?,
    tabGame: identical(tabGame, _keep) ? this.tabGame : tabGame as String?,
  );
  @override
  bool operator ==(Object other) =>
      other is RankingsQuery &&
      other.game == game &&
      other.region == region &&
      other.page == page &&
      other.metric == metric &&
      other.tabGame == tabGame;
  @override
  int get hashCode => Object.hash(game, region, page, metric, tabGame);
}

abstract class RankingsRepository {
  Future<RankingsPage> fetch(RankingsQuery q);
  Future<RankingsMe> fetchMe(RankingsQuery q);
}

class ApiRankingsRepository implements RankingsRepository {
  ApiRankingsRepository(this.api);
  final ApiClient api;
  @override
  Future<RankingsPage> fetch(RankingsQuery q) => api.getRankings(
    game: q.game,
    region: q.region,
    page: q.page,
    metric: q.metric,
    tabGame: q.tabGame,
  );
  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) => api.getRankingsMe(
    game: q.game,
    region: q.region,
    metric: q.metric,
    tabGame: q.tabGame,
  );
}
