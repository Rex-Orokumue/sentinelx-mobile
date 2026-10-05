import 'package:sentinelx_mobile/core/api/guide_models.dart';

Quest quest({int done = 1, bool claimed = false}) => Quest(
      id: 'battle_ready',
      steps: [
        QuestStep(key: 'profile_complete', done: done >= 1, target: QuestTarget.editProfile),
        QuestStep(key: 'first_tournament_entered', done: done >= 2, target: QuestTarget.tournaments),
        QuestStep(key: 'first_match_completed', done: done >= 3, target: QuestTarget.matches),
      ],
      totalCount: 3,
      allComplete: done >= 3,
      claimed: claimed,
      rewardXp: 100,
      rewardCoins: 50,
    );
