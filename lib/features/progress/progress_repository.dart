import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';

abstract class ProgressRepository {
  Future<MyProgress> progress();
  Future<HistoryPage<XpEvent>> xp(String? cursor);
  Future<HistoryPage<SxScoreEvent>> score(String? cursor);
  Future<HistoryPage<CoinTransaction>> coins(String? cursor);
}

class ApiProgressRepository implements ProgressRepository {
  ApiProgressRepository(this._api);
  final ApiClient _api;
  @override
  Future<MyProgress> progress() => _api.getMyProgress();
  @override
  Future<HistoryPage<XpEvent>> xp(String? cursor) => _api.getMyXpEvents(cursor: cursor);
  @override
  Future<HistoryPage<SxScoreEvent>> score(String? cursor) => _api.getMySxScoreEvents(cursor: cursor);
  @override
  Future<HistoryPage<CoinTransaction>> coins(String? cursor) => _api.getMyCoinTransactions(cursor: cursor);
}
