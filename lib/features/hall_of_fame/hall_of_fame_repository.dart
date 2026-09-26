import '../../core/api/api_client.dart';
import '../../core/api/progress_models.dart';

abstract class HallOfFameRepository {
  Future<HallOfFame> fetch({String? game});
}

class ApiHallOfFameRepository implements HallOfFameRepository {
  ApiHallOfFameRepository(this.api);
  final ApiClient api;
  @override
  Future<HallOfFame> fetch({String? game}) => api.getHallOfFame(game: game);
}
