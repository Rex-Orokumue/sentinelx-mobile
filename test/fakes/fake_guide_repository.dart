import 'dart:async';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';

class FakeGuideRepository implements GuideRepository {
  FakeGuideRepository({this.seed = const [], this.claimResult, this.claimError, this.claimDelay = false});
  List<Quest> seed;
  BadgeClaim? claimResult;
  ApiException? claimError;
  final bool claimDelay;
  int questsCalls = 0, claimCalls = 0;
  final _gate = Completer<void>();
  void completeClaim() => _gate.complete();

  @override
  Future<List<Quest>> quests() async {
    questsCalls++;
    return seed;
  }

  @override
  Future<BadgeClaim> claim() async {
    claimCalls++;
    if (claimDelay) await _gate.future;
    if (claimError != null) throw claimError!;
    // A successful claim is reflected by the next quests() call, like the real server.
    seed = [
      for (final q in seed)
        Quest(id: q.id, steps: q.steps, totalCount: q.totalCount, allComplete: q.allComplete, claimed: true, rewardXp: q.rewardXp, rewardCoins: q.rewardCoins),
    ];
    return claimResult!;
  }
}
