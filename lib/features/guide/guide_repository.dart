import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/guide_models.dart';
import '../../core/providers.dart';

abstract class GuideRepository {
  Future<List<Quest>> quests();
  Future<BadgeClaim> claim();
}

class ApiGuideRepository implements GuideRepository {
  ApiGuideRepository(this._api);
  final ApiClient _api;
  @override Future<List<Quest>> quests() async => (await _api.getGuideQuests()).quests;
  @override Future<BadgeClaim> claim() => _api.postGuideBadge();
}

final guideRepositoryProvider = Provider<GuideRepository>((ref) => ApiGuideRepository(ref.watch(apiClientProvider)));
