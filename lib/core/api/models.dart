class MeProfile {
  const MeProfile({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.whatsappNumber,
    required this.country,
    required this.locale,
    required this.membershipTier,
    required this.kycVerified,
    required this.deletionRequestedAt,
  });

  factory MeProfile.fromJson(Map<String, dynamic> j) => MeProfile(
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        whatsappNumber: j['whatsappNumber'] as String?,
        country: j['country'] as String?,
        locale: j['locale'] as String?,
        membershipTier: j['membershipTier'] as String?,
        kycVerified: j['kycVerified'] as bool,
        deletionRequestedAt: j['deletionRequestedAt'] as String?,
      );

  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? whatsappNumber;
  final String? country;
  final String? locale;
  final String? membershipTier;
  final bool kycVerified;
  final String? deletionRequestedAt;
}

class MeResponse {
  const MeResponse({
    required this.id,
    required this.email,
    required this.roles,
    required this.isStaff,
    required this.isAdmin,
    required this.profile,
  });

  factory MeResponse.fromJson(Map<String, dynamic> j) => MeResponse(
        id: j['id'] as String,
        email: j['email'] as String?,
        roles: (j['roles'] as List<dynamic>).cast<String>(),
        isStaff: j['isStaff'] as bool,
        isAdmin: j['isAdmin'] as bool,
        profile: j['profile'] == null ? null : MeProfile.fromJson(j['profile'] as Map<String, dynamic>),
      );

  final String id;
  final String? email;
  final List<String> roles;
  final bool isStaff;
  final bool isAdmin;
  final MeProfile? profile;
}

class DailyLoginAward {
  const DailyLoginAward({
    required this.awardedToday,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.streak,
    required this.milestone,
  });

  factory DailyLoginAward.fromJson(Map<String, dynamic> j) => DailyLoginAward(
        awardedToday: j['awardedToday'] as bool,
        coinsAwarded: (j['coinsAwarded'] as num).toInt(),
        xpAwarded: (j['xpAwarded'] as num).toInt(),
        streak: (j['streak'] as num).toInt(),
        milestone: j['milestone'] as String?,
      );

  final bool awardedToday;
  final int coinsAwarded;
  final int xpAwarded;
  final int streak;
  final String? milestone; // 'week' | 'month' | null
}

class SessionStartResponse {
  const SessionStartResponse({required this.dailyLogin, required this.deletionRequestedAt});

  factory SessionStartResponse.fromJson(Map<String, dynamic> j) => SessionStartResponse(
        dailyLogin: DailyLoginAward.fromJson(j['dailyLogin'] as Map<String, dynamic>),
        deletionRequestedAt: j['deletionRequestedAt'] as String?,
      );

  final DailyLoginAward dailyLogin;
  final String? deletionRequestedAt;
}

class HomeGame {
  const HomeGame({required this.name, required this.iconUrl, required this.slug, required this.category});
  factory HomeGame.fromJson(Map<String, dynamic> j) => HomeGame(
        name: j['name'] as String,
        iconUrl: j['iconUrl'] as String?,
        slug: j['slug'] as String?,
        category: j['category'] as String?,
      );
  final String name;
  final String? iconUrl;
  final String? slug;
  final String? category;
}

class HomeTournamentCard {
  const HomeTournamentCard({
    required this.id,
    required this.title,
    required this.slug,
    required this.status,
    required this.prizePool,
    required this.registrationFee,
    required this.tournamentStart,
    required this.registrationEnd,
    required this.tournamentEnd,
    required this.maxPlayers,
    required this.format,
    required this.tournamentType,
    required this.cardImageUrl,
    required this.game,
  });

  factory HomeTournamentCard.fromJson(Map<String, dynamic> j) => HomeTournamentCard(
        id: j['id'] as String,
        title: j['title'] as String,
        slug: j['slug'] as String,
        status: j['status'] as String,
        prizePool: (j['prizePool'] as num).toInt(),
        registrationFee: (j['registrationFee'] as num).toInt(),
        tournamentStart: j['tournamentStart'] as String?,
        registrationEnd: j['registrationEnd'] as String?,
        tournamentEnd: j['tournamentEnd'] as String?,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt(),
        format: j['format'] as String?,
        tournamentType: j['tournamentType'] as String?,
        cardImageUrl: j['cardImageUrl'] as String?,
        game: j['game'] == null ? null : HomeGame.fromJson(j['game'] as Map<String, dynamic>),
      );

  final String id;
  final String title;
  final String slug;
  final String status;
  final int prizePool;
  final int registrationFee;
  final String? tournamentStart;
  final String? registrationEnd;
  final String? tournamentEnd;
  final int? maxPlayers;
  final String? format;
  final String? tournamentType;
  final String? cardImageUrl;
  final HomeGame? game;
}

class HomeLeaderboardPlayer {
  const HomeLeaderboardPlayer({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.wins,
    required this.totalMatches,
    required this.sxScore,
    required this.sentinelTier,
    required this.membershipTier,
    required this.equippedAvatarBorder,
  });

  factory HomeLeaderboardPlayer.fromJson(Map<String, dynamic> j) => HomeLeaderboardPlayer(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        wins: (j['wins'] as num).toInt(),
        totalMatches: (j['totalMatches'] as num).toInt(),
        sxScore: (j['sxScore'] as num).toInt(),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String?,
        equippedAvatarBorder: j['equippedAvatarBorder'] as String?,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int wins;
  final int totalMatches;
  final int sxScore;
  final String? sentinelTier;
  final String? membershipTier;
  final String? equippedAvatarBorder;
}

class HomeBanner {
  const HomeBanner({required this.title, required this.imageUrl, required this.linkUrl});
  factory HomeBanner.fromJson(Map<String, dynamic> j) =>
      HomeBanner(title: j['title'] as String, imageUrl: j['imageUrl'] as String?, linkUrl: j['linkUrl'] as String?);
  final String title;
  final String? imageUrl;
  final String? linkUrl;
}

class HallOfFameTeaser {
  const HallOfFameTeaser({
    required this.slug,
    required this.title,
    required this.prizePool,
    required this.gameName,
    required this.championName,
  });
  factory HallOfFameTeaser.fromJson(Map<String, dynamic> j) => HallOfFameTeaser(
        slug: j['slug'] as String,
        title: j['title'] as String,
        prizePool: (j['prizePool'] as num).toInt(),
        gameName: j['gameName'] as String?,
        championName: j['championName'] as String,
      );
  final String slug;
  final String title;
  final int prizePool;
  final String? gameName;
  final String championName;
}

class HomeStats {
  const HomeStats({required this.playerCount, required this.tournamentCount, required this.prizesPaidOut});
  factory HomeStats.fromJson(Map<String, dynamic> j) => HomeStats(
        playerCount: (j['playerCount'] as num).toInt(),
        tournamentCount: (j['tournamentCount'] as num).toInt(),
        prizesPaidOut: (j['prizesPaidOut'] as num).toInt(),
      );
  final int playerCount;
  final int tournamentCount;
  final int prizesPaidOut;
}

class HomeSummary {
  const HomeSummary({
    required this.banner,
    required this.featuredTournament,
    required this.upcomingTournaments,
    required this.leaderboardTeaser,
    required this.hallOfFame,
    required this.stats,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        banner: j['banner'] == null ? null : HomeBanner.fromJson(j['banner'] as Map<String, dynamic>),
        featuredTournament:
            j['featuredTournament'] == null ? null : HomeTournamentCard.fromJson(j['featuredTournament'] as Map<String, dynamic>),
        upcomingTournaments: (j['upcomingTournaments'] as List<dynamic>)
            .map((e) => HomeTournamentCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        leaderboardTeaser: (j['leaderboardTeaser'] as List<dynamic>)
            .map((e) => HomeLeaderboardPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        hallOfFame: j['hallOfFame'] == null ? null : HallOfFameTeaser.fromJson(j['hallOfFame'] as Map<String, dynamic>),
        stats: HomeStats.fromJson(j['stats'] as Map<String, dynamic>),
      );

  final HomeBanner? banner;
  final HomeTournamentCard? featuredTournament;
  final List<HomeTournamentCard> upcomingTournaments;
  final List<HomeLeaderboardPlayer> leaderboardTeaser;
  final HallOfFameTeaser? hallOfFame;
  final HomeStats stats;
}
