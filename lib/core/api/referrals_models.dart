class ReferralMilestone {
  const ReferralMilestone({required this.count, required this.bonusCoins});

  factory ReferralMilestone.fromJson(Map<String, dynamic> json) =>
      ReferralMilestone(
        count: (json['count'] as num).toInt(),
        bonusCoins: (json['bonusCoins'] as num?)?.toInt(),
      );

  final int count;
  final int? bonusCoins;
}

class ReferredPlayer {
  const ReferredPlayer({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.tier,
    required this.frameUrl,
    required this.status,
    required this.date,
    required this.coinsAwarded,
  });

  factory ReferredPlayer.fromJson(Map<String, dynamic> json) => ReferredPlayer(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    tier: json['tier'] as String,
    frameUrl: json['frameUrl'] as String?,
    status: json['status'] as String,
    date: DateTime.parse(json['date'] as String).toUtc(),
    coinsAwarded: (json['coinsAwarded'] as num?)?.toInt(),
  );

  final String id;
  final String name;
  final String? avatarUrl;
  final String tier;
  final String? frameUrl;
  final String status;
  final DateTime date;
  final int? coinsAwarded;
}

class ReferralMilestoneHistory {
  const ReferralMilestoneHistory({
    required this.id,
    required this.description,
    required this.coins,
    required this.date,
  });

  factory ReferralMilestoneHistory.fromJson(Map<String, dynamic> json) =>
      ReferralMilestoneHistory(
        id: json['id'] as String,
        description: json['description'] as String,
        coins: (json['coins'] as num).toInt(),
        date: DateTime.parse(json['date'] as String).toUtc(),
      );

  final String id;
  final String description;
  final int coins;
  final DateTime date;
}

class ReferralOverview {
  const ReferralOverview({
    required this.username,
    required this.shareUrl,
    required this.totalReferrals,
    required this.convertedCount,
    required this.totalCoinsEarned,
    required this.nextMilestone,
    required this.invited,
    required this.milestoneHistory,
  });

  factory ReferralOverview.fromJson(
    Map<String, dynamic> json,
  ) => ReferralOverview(
    username: json['username'] as String?,
    shareUrl: json['shareUrl'] as String?,
    totalReferrals: (json['totalReferrals'] as num).toInt(),
    convertedCount: (json['convertedCount'] as num).toInt(),
    totalCoinsEarned: (json['totalCoinsEarned'] as num).toInt(),
    nextMilestone: json['nextMilestone'] == null
        ? null
        : ReferralMilestone.fromJson(
            json['nextMilestone'] as Map<String, dynamic>,
          ),
    invited: (json['invited'] as List<dynamic>)
        .map((item) => ReferredPlayer.fromJson(item as Map<String, dynamic>))
        .toList(),
    milestoneHistory: (json['milestoneHistory'] as List<dynamic>)
        .map(
          (item) =>
              ReferralMilestoneHistory.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );

  final String? username;
  final String? shareUrl;
  final int totalReferrals;
  final int convertedCount;
  final int totalCoinsEarned;
  final ReferralMilestone? nextMilestone;
  final List<ReferredPlayer> invited;
  final List<ReferralMilestoneHistory> milestoneHistory;
}
