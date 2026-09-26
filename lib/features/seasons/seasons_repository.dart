import '../../core/api/api_client.dart';
import '../../core/api/progress_models.dart';

abstract class SeasonsRepository {
  Future<List<SeasonSummary>> list();
  Future<SeasonDetail> detail(String slug);
}

class ApiSeasonsRepository implements SeasonsRepository {
  ApiSeasonsRepository(this.api);
  final ApiClient api;
  @override
  Future<List<SeasonSummary>> list() => api.getSeasons();
  @override
  Future<SeasonDetail> detail(String s) => api.getSeasonDetail(s);
}
