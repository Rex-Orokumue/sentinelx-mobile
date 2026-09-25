int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();

List<T> _list<T>(Object? v, T Function(Map<String, dynamic> j) parse) =>
    (v as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();

T? _opt<T>(Object? v, T Function(Map<String, dynamic> j) parse) => v == null ? null : parse(v as Map<String, dynamic>);

class PlayerListItem {
  const PlayerListItem({
    required this.username, required this.displayName, required this.avatarUrl, required this.sxScore,
    required this.sentinelTier, required this.membershipTier, required this.equippedAvatarBorder,
  });

  factory PlayerListItem.fromJson(Map<String, dynamic> j) => PlayerListItem(
        username: j['username'] as String,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String,
        equippedAvatarBorder: j['equippedAvatarBorder'] as String?,
      );

  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final String? equippedAvatarBorder;

  String get label => displayName ?? username;
}

class FollowEntry {
  const FollowEntry({required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.membershipTier});

  factory FollowEntry.fromJson(Map<String, dynamic> j) => FollowEntry(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        membershipTier: j['membershipTier'] as String,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String membershipTier;

  /// A deleted/anonymised account has no username; the API never invents one.
  bool get isDeleted => username == null;
  String get label => displayName ?? username ?? '';
}

class FollowSets {
  const FollowSets({required this.followingIds, required this.followerIds});

  factory FollowSets.fromJson(Map<String, dynamic> j) => FollowSets(
        followingIds: (j['followingIds'] as List<dynamic>).cast<String>().toSet(),
        followerIds: (j['followerIds'] as List<dynamic>).cast<String>().toSet(),
      );

  final Set<String> followingIds;
  final Set<String> followerIds;

  FollowSets copyWith({Set<String>? followingIds, Set<String>? followerIds}) =>
      FollowSets(followingIds: followingIds ?? this.followingIds, followerIds: followerIds ?? this.followerIds);
}

class FollowOutcome {
  const FollowOutcome({required this.following, required this.created});

  /// PUT returns `{following: true, created}`; DELETE returns `{following: false}` (no `created`).
  factory FollowOutcome.fromJson(Map<String, dynamic> j) =>
      FollowOutcome(following: j['following'] as bool, created: j['created'] as bool? ?? false);

  final bool following;
  final bool created;
}

class ProfileHeader {
  const ProfileHeader({
    required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.frameUrl,
    required this.profileTheme, required this.usernameColour, required this.country, required this.bio,
    required this.createdAt, required this.sxScore, required this.sentinelTier, required this.membershipTier, required this.xp,
  });

  factory ProfileHeader.fromJson(Map<String, dynamic> j) => ProfileHeader(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        frameUrl: j['frameUrl'] as String?,
        profileTheme: j['profileTheme'] as String?,
        usernameColour: j['usernameColour'] as String?,
        country: j['country'] as String?,
        bio: j['bio'] as String?,
        createdAt: j['createdAt'] as String?,
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String,
        xp: _int(j['xp']),
      );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? frameUrl;
  final String? profileTheme;
  final String? usernameColour;
  final String? country;
  final String? bio;
  final String? createdAt;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final int xp;

  String get label => displayName ?? username;
}

class CategoryStat {
  const CategoryStat({required this.category, required this.scored, required this.conceded});
  factory CategoryStat.fromJson(Map<String, dynamic> j) =>
      CategoryStat(category: j['category'] as String, scored: _int(j['scored']), conceded: _int(j['conceded']));
  final String category;
  final int scored;
  final int conceded;
}

class ProfileStats {
  const ProfileStats({
    required this.totalMatches, required this.wins, required this.losses, required this.goalsScored, required this.goalsConceded,
    required this.totalTitles, required this.tournamentsPlayed, required this.currentStreak, required this.rank,
    required this.totalRankedPlayers, required this.followerCount, required this.followingCount, required this.categoryStats,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        totalMatches: _int(j['totalMatches']),
        wins: _int(j['wins']),
        losses: _int(j['losses']),
        goalsScored: _int(j['goalsScored']),
        goalsConceded: _int(j['goalsConceded']),
        totalTitles: _int(j['totalTitles']),
        tournamentsPlayed: _int(j['tournamentsPlayed']),
        currentStreak: _int(j['currentStreak']),
        rank: _intOrNull(j['rank']),
        totalRankedPlayers: _intOrNull(j['totalRankedPlayers']),
        followerCount: _int(j['followerCount']),
        followingCount: _int(j['followingCount']),
        categoryStats: _list(j['categoryStats'], CategoryStat.fromJson),
      );

  final int totalMatches;
  final int wins;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int totalTitles;
  final int tournamentsPlayed;
  final int currentStreak;
  final int? rank;
  final int? totalRankedPlayers;
  final int followerCount;
  final int followingCount;
  final List<CategoryStat> categoryStats;
}

class ProfileTitle {
  const ProfileTitle({required this.tournamentTitle, required this.tournamentSlug, required this.gameName, required this.date});
  factory ProfileTitle.fromJson(Map<String, dynamic> j) => ProfileTitle(
        tournamentTitle: j['tournamentTitle'] as String,
        tournamentSlug: j['tournamentSlug'] as String,
        gameName: j['gameName'] as String?,
        date: j['date'] as String?,
      );
  final String tournamentTitle;
  final String tournamentSlug;
  final String? gameName;
  final String? date;
}

class ProfileMatch {
  const ProfileMatch({
    required this.id, required this.opponentName, required this.playerScore, required this.opponentScore,
    required this.outcome, required this.tournamentTitle, required this.completedAt,
  });
  factory ProfileMatch.fromJson(Map<String, dynamic> j) => ProfileMatch(
        id: j['id'] as String,
        opponentName: j['opponentName'] as String,
        playerScore: _int(j['playerScore']),
        opponentScore: _int(j['opponentScore']),
        outcome: j['outcome'] as String,
        tournamentTitle: j['tournamentTitle'] as String?,
        completedAt: j['completedAt'] as String?,
      );
  final String id;
  final String opponentName;
  final int playerScore;
  final int opponentScore;
  final String outcome;
  final String? tournamentTitle;
  final String? completedAt;
}

class UnlockedAchievement {
  const UnlockedAchievement({
    required this.slug, required this.name, required this.description, required this.category,
    required this.unlockedAt, required this.unlockCount,
  });
  factory UnlockedAchievement.fromJson(Map<String, dynamic> j) => UnlockedAchievement(
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        category: j['category'] as String,
        unlockedAt: j['unlockedAt'] as String,
        unlockCount: _int(j['unlockCount']),
      );
  final String slug;
  final String name;
  final String description;
  final String category;
  final String unlockedAt;
  final int unlockCount;
}

class Achievements {
  const Achievements({required this.total, required this.unlockedCount, required this.unlocked, required this.showcase});
  factory Achievements.fromJson(Map<String, dynamic> j) => Achievements(
        total: _int(j['total']),
        unlockedCount: _int(j['unlockedCount']),
        unlocked: _list(j['unlocked'], UnlockedAchievement.fromJson),
        showcase: (j['showcase'] as List<dynamic>).cast<String>(),
      );
  final int total;
  final int unlockedCount;
  final List<UnlockedAchievement> unlocked;
  final List<String> showcase;

  int get lockedCount => total > unlockedCount ? total - unlockedCount : 0;
}

class ProfilePost {
  const ProfilePost({required this.id, required this.content, required this.postType, required this.createdAt});
  factory ProfilePost.fromJson(Map<String, dynamic> j) => ProfilePost(
        id: j['id'] as String,
        content: j['content'] as String,
        postType: j['postType'] as String,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final String content;
  final String postType;
  final String createdAt;
}

class GalleryImage {
  const GalleryImage({required this.id, required this.imageUrl});
  factory GalleryImage.fromJson(Map<String, dynamic> j) => GalleryImage(id: j['id'] as String, imageUrl: j['imageUrl'] as String);
  final String id;
  final String imageUrl;
}

class PlayerProfile {
  const PlayerProfile({
    required this.player, required this.stats, required this.titles, required this.recentMatches,
    required this.achievements, required this.posts, required this.gallery,
  });
  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        player: ProfileHeader.fromJson(j['player'] as Map<String, dynamic>),
        stats: ProfileStats.fromJson(j['stats'] as Map<String, dynamic>),
        titles: _list(j['titles'], ProfileTitle.fromJson),
        recentMatches: _list(j['recentMatches'], ProfileMatch.fromJson),
        achievements: Achievements.fromJson(j['achievements'] as Map<String, dynamic>),
        posts: _list(j['posts'], ProfilePost.fromJson),
        gallery: _list(j['gallery'], GalleryImage.fromJson),
      );
  final ProfileHeader player;
  final ProfileStats stats;
  final List<ProfileTitle> titles;
  final List<ProfileMatch> recentMatches;
  final Achievements achievements;
  final List<ProfilePost> posts;
  final List<GalleryImage> gallery;
}

class TierProgress {
  const TierProgress({required this.current, required this.next, required this.xpIntoTier, required this.xpForNextTier});
  factory TierProgress.fromJson(Map<String, dynamic> j) => TierProgress(
        current: j['current'] as String,
        next: j['next'] as String,
        xpIntoTier: _int(j['xpIntoTier']),
        xpForNextTier: _int(j['xpForNextTier']),
      );
  final String current;
  final String next;
  final int xpIntoTier;
  final int xpForNextTier;

  double get fraction => xpForNextTier <= 0 ? 0.0 : (xpIntoTier / xpForNextTier).clamp(0.0, 1.0);
}

class SeasonStanding {
  const SeasonStanding({
    required this.seasonName, required this.rank, required this.points, required this.pointsAtRankSixteen,
    required this.monthlyRank, required this.monthlyPoints,
  });
  factory SeasonStanding.fromJson(Map<String, dynamic> j) => SeasonStanding(
        seasonName: j['seasonName'] as String?,
        rank: _intOrNull(j['rank']),
        points: _int(j['points']),
        pointsAtRankSixteen: _int(j['pointsAtRankSixteen']),
        monthlyRank: _intOrNull(j['monthlyRank']),
        monthlyPoints: _int(j['monthlyPoints']),
      );
  final String? seasonName;
  final int? rank;
  final int points;
  final int pointsAtRankSixteen;
  final int? monthlyRank;
  final int monthlyPoints;
}

class MyProgress {
  const MyProgress({
    required this.xp, required this.membershipTier, required this.tierProgress, required this.sxScore,
    required this.sentinelTier, required this.coinBalance, required this.seasonStanding,
  });
  factory MyProgress.fromJson(Map<String, dynamic> j) => MyProgress(
        xp: _int(j['xp']),
        membershipTier: j['membershipTier'] as String,
        tierProgress: _opt(j['tierProgress'], TierProgress.fromJson),
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        coinBalance: _int(j['coinBalance']),
        seasonStanding: _opt(j['seasonStanding'], SeasonStanding.fromJson),
      );
  final int xp;
  final String membershipTier;
  final TierProgress? tierProgress;
  final int sxScore;
  final String? sentinelTier;
  final int coinBalance;
  final SeasonStanding? seasonStanding;
}

class HistoryPage<T> {
  const HistoryPage({required this.items, required this.nextCursor});

  static HistoryPage<T> parse<T>(Map<String, dynamic> j, T Function(Map<String, dynamic> j) item) =>
      HistoryPage(items: _list(j['items'], item), nextCursor: j['nextCursor'] as String?);

  final List<T> items;
  final String? nextCursor;
}

class XpEvent {
  const XpEvent({required this.id, required this.xp, required this.source, required this.createdAt});
  factory XpEvent.fromJson(Map<String, dynamic> j) =>
      XpEvent(id: j['id'] as String, xp: _int(j['xp']), source: j['source'] as String, createdAt: j['createdAt'] as String);
  final String id;
  final int xp;
  final String source;
  final String createdAt;
}

class SxScoreEvent {
  const SxScoreEvent({required this.id, required this.eventType, required this.pointsDelta, required this.matchId, required this.createdAt});
  factory SxScoreEvent.fromJson(Map<String, dynamic> j) => SxScoreEvent(
        id: j['id'] as String,
        eventType: j['eventType'] as String,
        pointsDelta: _int(j['pointsDelta']),
        matchId: j['matchId'] as String?,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final String eventType;
  final int pointsDelta;
  final String? matchId;
  final String createdAt;
}

class CoinTransaction {
  const CoinTransaction({
    required this.id, required this.amount, required this.balanceAfter, required this.source,
    required this.description, required this.createdAt,
  });
  factory CoinTransaction.fromJson(Map<String, dynamic> j) => CoinTransaction(
        id: j['id'] as String,
        amount: _int(j['amount']),
        balanceAfter: _int(j['balanceAfter']),
        source: j['source'] as String,
        description: j['description'] as String?,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final int amount;
  final int balanceAfter;
  final String source;
  final String? description;
  final String createdAt;
}
