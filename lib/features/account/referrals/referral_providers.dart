import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/referrals_models.dart';
import '../../../core/providers.dart';

abstract class ReferralRepository {
  Future<ReferralOverview> overview();
}

class ApiReferralRepository implements ReferralRepository {
  ApiReferralRepository(this._api);

  final ApiClient _api;

  @override
  Future<ReferralOverview> overview() => _api.getMyReferrals();
}

final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => ApiReferralRepository(ref.watch(apiClientProvider)),
);

final referralOverviewProvider = FutureProvider.autoDispose<ReferralOverview?>((
  ref,
) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(referralRepositoryProvider).overview();
});
