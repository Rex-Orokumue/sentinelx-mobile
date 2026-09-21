import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

abstract class HomeRepository {
  Future<HomeSummary> fetchHome();
}

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._api);
  final ApiClient _api;

  @override
  Future<HomeSummary> fetchHome() => _api.getHome();
}
