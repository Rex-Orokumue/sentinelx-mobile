import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/quest_routes.dart';
import '../../fakes/fake_guide_repository.dart';

Quest _q({bool all = true, bool claimed = false}) => Quest(id: 'battle_ready', steps: [QuestStep(key: 'a', done: all)], totalCount: 1, allComplete: all, claimed: claimed, rewardXp: 100, rewardCoins: 50);
ProviderContainer _c(FakeGuideRepository repo, {String? viewer = 'u1'}) {
  final c = ProviderContainer(overrides: [
    viewerIdProvider.overrideWith((ref) async => viewer),
    guideRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('signed out: no request, empty list', () async {
    final repo = FakeGuideRepository(seed: [_q()]);
    expect(await _c(repo, viewer: null).read(questsProvider.future), isEmpty);
    expect(repo.questsCalls, 0);
  });
  test('signed in: loads the quests once', () async {
    final repo = FakeGuideRepository(seed: [_q()]);
    final c = _c(repo);
    expect(battleReady(await c.read(questsProvider.future))?.id, 'battle_ready');
    expect(repo.questsCalls, 1);
  });
  test('claim success invalidates the quests (they are refetched)', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 100, coins: 50));
    final c = _c(repo);
    await c.read(questsProvider.future);
    c.listen(questsProvider, (_, _) {});
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.claimed);
    await c.read(questsProvider.future);
    expect(repo.questsCalls, 2);
  });
  test('a failed claim maps the ApiException code and allows another attempt', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimError: const ApiException(status: 409, code: 'quest_incomplete', message: 'x'));
    final c = _c(repo);
    c.listen(claimBadgeProvider, (_, _) {});
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.failed);
    expect(c.read(claimBadgeProvider).errorCode, 'quest_incomplete');
    repo.claimError = null;
    repo.claimResult = const BadgeClaim(alreadyClaimed: true, xp: 100, coins: 50);
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.claimed);
  });
  test('a second claim() while one is in flight is ignored (one request)', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 1, coins: 1), claimDelay: true);
    final c = _c(repo);
    c.listen(claimBadgeProvider, (_, _) {});
    final first = c.read(claimBadgeProvider.notifier).claim();
    final second = c.read(claimBadgeProvider.notifier).claim();
    repo.completeClaim();
    await Future.wait([first, second]);
    expect(repo.claimCalls, 1);
  });
  test('quest step routes', () {
    expect(questStepRoute(QuestTarget.editProfile), '/account/profile');
    expect(questStepRoute(QuestTarget.tournaments), '/tournaments');
    expect(questStepRoute(QuestTarget.matches), '/');
    expect(questStepRoute(null), isNull);
  });
}
