import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';

void main() {
  final good = {
    'quests': [
      {'id': 'battle_ready', 'steps': [
        {'key': 'profile_complete', 'done': true, 'target': 'edit_profile'},
        {'key': 'first_tournament_entered', 'done': false, 'target': 'tournaments'},
        {'key': 'first_match_completed', 'done': false, 'target': 'matches'},
      ], 'doneCount': 1, 'totalCount': 3, 'allComplete': false, 'claimed': false, 'reward': {'xp': 100, 'coins': 50}},
    ],
  };
  test('parses a quest and counts done steps itself', () {
    final q = GuideQuests.fromJson(good).quests.single;
    expect(q.id, 'battle_ready');
    expect(q.doneCount, 1);
    expect(q.steps.first.target, QuestTarget.editProfile);
    expect([q.rewardXp, q.rewardCoins], [100, 50]);
  });
  test('an unknown target degrades to null, an unknown step key is kept (generic label later)', () {
    final s = QuestStep.tryParse({'key': 'brand_new_step', 'done': false, 'target': 'wallet_screen'})!;
    expect(s.key, 'brand_new_step');
    expect(s.target, isNull);
  });
  test('a malformed quest or step is skipped, never thrown', () {
    final r = GuideQuests.fromJson({'quests': [1, {'id': 5}, ...(good['quests']! as List)]});
    expect(r.quests, hasLength(1));
    final withBadStep = Quest.tryParse({'id': 'x', 'steps': [{'key': 1}, {'key': 'a', 'done': true}], 'totalCount': 1, 'allComplete': true, 'claimed': false, 'reward': {'xp': 1, 'coins': 1}})!;
    expect(withBadStep.steps, hasLength(1));
  });
  test('missing quests list yields an empty list', () {
    expect(GuideQuests.fromJson(const {}).quests, isEmpty);
  });
  test('BadgeClaim parses', () {
    final c = BadgeClaim.fromJson({'claimed': true, 'alreadyClaimed': true, 'xp': 100, 'coins': 50});
    expect([c.alreadyClaimed, c.xp, c.coins], [true, 100, 50]);
  });
}
