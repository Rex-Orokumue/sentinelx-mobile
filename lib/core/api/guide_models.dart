enum QuestTarget {
  editProfile, tournaments, matches;
  static QuestTarget? parse(Object? v) => switch (v) {
        'edit_profile' => editProfile,
        'tournaments' => tournaments,
        'matches' => matches,
        _ => null,
      };
}

class QuestStep {
  const QuestStep({required this.key, required this.done, this.target});
  final String key;
  final bool done;
  final QuestTarget? target;
  static QuestStep? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final key = j['key'], done = j['done'];
    if (key is! String || done is! bool) return null;
    return QuestStep(key: key, done: done, target: QuestTarget.parse(j['target']));
  }
}

class Quest {
  const Quest({required this.id, required this.steps, required this.totalCount, required this.allComplete, required this.claimed, required this.rewardXp, required this.rewardCoins});
  final String id;
  final List<QuestStep> steps;
  final int totalCount;
  final bool allComplete, claimed;
  final int rewardXp, rewardCoins;
  int get doneCount => steps.where((s) => s.done).length;
  static Quest? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final id = j['id'], steps = j['steps'];
    if (id is! String || steps is! List) return null;
    final reward = j['reward'] is Map<String, dynamic> ? j['reward'] as Map<String, dynamic> : const <String, dynamic>{};
    return Quest(
      id: id,
      steps: steps.map(QuestStep.tryParse).whereType<QuestStep>().toList(),
      totalCount: j['totalCount'] is int ? j['totalCount'] as int : steps.length,
      allComplete: j['allComplete'] == true,
      claimed: j['claimed'] == true,
      rewardXp: reward['xp'] is int ? reward['xp'] as int : 0,
      rewardCoins: reward['coins'] is int ? reward['coins'] as int : 0,
    );
  }
}

class GuideQuests {
  const GuideQuests(this.quests);
  final List<Quest> quests;
  factory GuideQuests.fromJson(Map<String, dynamic> j) {
    final raw = j['quests'];
    return GuideQuests(raw is List ? raw.map(Quest.tryParse).whereType<Quest>().toList() : const []);
  }
}

class BadgeClaim {
  const BadgeClaim({required this.alreadyClaimed, required this.xp, required this.coins});
  final bool alreadyClaimed;
  final int xp, coins;
  factory BadgeClaim.fromJson(Map<String, dynamic> j) => BadgeClaim(
        alreadyClaimed: j['alreadyClaimed'] == true,
        xp: j['xp'] is int ? j['xp'] as int : 0,
        coins: j['coins'] is int ? j['coins'] as int : 0,
      );
}
