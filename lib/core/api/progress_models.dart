int _int(Object? v) => (v as num).toInt();

List<T> _list<T>(Object? v, T Function(Map<String, dynamic> j) parse) =>
    (v as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();

T? _opt<T>(Object? v, T Function(Map<String, dynamic> j) parse) =>
    v == null ? null : parse(v as Map<String, dynamic>);

class PlayerCard {
  const PlayerCard({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.frameUrl,
    required this.country,
    required this.sxScore,
    required this.sentinelTier,
    required this.membershipTier,
    required this.kycVerified,
    required this.isDeleted,
  });

  factory PlayerCard.fromJson(Map<String, dynamic> j) => PlayerCard(
    id: j['id'] as String,
    username: j['username'] as String?,
    displayName: j['displayName'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    frameUrl: j['frameUrl'] as String?,
    country: j['country'] as String?,
    sxScore: _int(j['sxScore']),
    sentinelTier: j['sentinelTier'] as String?,
    membershipTier: j['membershipTier'] as String,
    kycVerified: j['kycVerified'] as bool,
    isDeleted: j['isDeleted'] as bool,
  );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? frameUrl;
  final String? country;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final bool kycVerified;
  final bool isDeleted;

  String get label => displayName ?? username ?? '';
}

class Trend {
  const Trend({required this.direction, required this.delta});
  factory Trend.fromJson(Map<String, dynamic> j) =>
      Trend(direction: j['direction'] as String, delta: _int(j['delta']));

  /// up | down | flat | new
  final String direction;
  final int delta;
}

class RankingRow {
  const RankingRow({
    required this.rank,
    required this.player,
    required this.wins,
    required this.losses,
    required this.totalMatches,
    required this.winRate,
    required this.goalsScored,
    required this.goalsConceded,
    required this.goalDiff,
    required this.totalTitles,
    required this.metricValue,
    required this.winsByGame,
    required this.trend,
    required this.streak,
  });

  factory RankingRow.fromJson(Map<String, dynamic> j) => RankingRow(
    rank: _int(j['rank']),
    player: PlayerCard.fromJson(j['player'] as Map<String, dynamic>),
    wins: _int(j['wins']),
    losses: _int(j['losses']),
    totalMatches: _int(j['totalMatches']),
    winRate: (j['winRate'] as num).toDouble(),
    goalsScored: _int(j['goalsScored']),
    goalsConceded: _int(j['goalsConceded']),
    goalDiff: _int(j['goalDiff']),
    totalTitles: _int(j['totalTitles']),
    metricValue: j['metricValue'] as num,
    winsByGame: _list(j['winsByGame'], WinsByGame.fromJson),
    trend: Trend.fromJson(j['trend'] as Map<String, dynamic>),
    streak: _int(j['streak']),
  );

  final int rank;
  final PlayerCard player;
  final int wins;
  final int losses;
  final int totalMatches;
  final double winRate;
  final int goalsScored;
  final int goalsConceded;
  final int goalDiff;
  final int totalTitles;
  final num metricValue;
  final List<WinsByGame> winsByGame;
  final Trend trend;
  final int streak;
}

class WinsByGame {
  const WinsByGame({
    required this.gameId,
    required this.gameName,
    required this.wins,
  });
  factory WinsByGame.fromJson(Map<String, dynamic> j) => WinsByGame(
    gameId: j['gameId'] as String,
    gameName: j['gameName'] as String,
    wins: _int(j['wins']),
  );
  final String gameId;
  final String gameName;
  final int wins;
}

class GameChip {
  const GameChip({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
  });
  factory GameChip.fromJson(Map<String, dynamic> j) => GameChip(
    id: j['id'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
  );
  final String id;
  final String slug;
  final String name;
  final String category;
}

class RankingsScope {
  const RankingsScope({
    required this.game,
    required this.region,
    required this.serverMetric,
    required this.metric,
    required this.metricLabel,
    required this.tabGame,
  });
  factory RankingsScope.fromJson(Map<String, dynamic> j) => RankingsScope(
    game: j['game'] as String?,
    region: j['region'] as String?,
    serverMetric: j['serverMetric'] as String,
    metric: j['metric'] as String,
    metricLabel: j['metricLabel'] as String,
    tabGame: j['tabGame'] as String?,
  );
  final String? game;
  final String? region;

  final String serverMetric;
  final String metric;
  final String metricLabel;
  final String? tabGame;
}

class MetricTab {
  const MetricTab({required this.key, required this.label});
  factory MetricTab.fromJson(Map<String, dynamic> j) =>
      MetricTab(key: j['key'] as String, label: j['label'] as String);
  final String key;
  final String label;
}

class SubGame {
  const SubGame({required this.slug, required this.name});
  factory SubGame.fromJson(Map<String, dynamic> j) =>
      SubGame(slug: j['slug'] as String, name: j['name'] as String);
  final String slug;
  final String name;
}

class PageInfo {
  const PageInfo({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.perPage,
  });
  factory PageInfo.fromJson(Map<String, dynamic> j) => PageInfo(
    page: _int(j['page']),
    totalPages: _int(j['totalPages']),
    total: _int(j['total']),
    perPage: _int(j['perPage']),
  );
  final int page;
  final int totalPages;
  final int total;
  final int perPage;
}

class RankingsStats {
  const RankingsStats({
    required this.playersRanked,
    required this.gamesIncluded,
    required this.totalMatches,
    required this.prizesAwarded,
  });
  factory RankingsStats.fromJson(Map<String, dynamic> j) => RankingsStats(
    playersRanked: _int(j['playersRanked']),
    gamesIncluded: _int(j['gamesIncluded']),
    totalMatches: _int(j['totalMatches']),
    prizesAwarded: j['prizesAwarded'] as num,
  );
  final int playersRanked;
  final int gamesIncluded;
  final int totalMatches;
  final num prizesAwarded;
}

class Highlights {
  const Highlights({
    required this.topScore,
    required this.topTitles,
    required this.topWinRate,
    required this.topStreak,
    required this.topStreakValue,
  });
  factory Highlights.fromJson(Map<String, dynamic> j) => Highlights(
    topScore: _opt(j['topScore'], PlayerCard.fromJson),
    topTitles: _opt(j['topTitles'], PlayerCard.fromJson),
    topWinRate: _opt(j['topWinRate'], PlayerCard.fromJson),
    topStreak: _opt(j['topStreak'], PlayerCard.fromJson),
    topStreakValue: _int(j['topStreakValue']),
  );
  final PlayerCard? topScore;
  final PlayerCard? topTitles;
  final PlayerCard? topWinRate;
  final PlayerCard? topStreak;
  final int topStreakValue;
}

class RankingsPage {
  const RankingsPage({
    required this.scope,
    required this.rows,
    required this.tabs,
    required this.subGames,
    required this.subGamesAllLabel,
    required this.page,
    required this.games,
    required this.regions,
    required this.stats,
    required this.highlights,
  });
  factory RankingsPage.fromJson(Map<String, dynamic> j) => RankingsPage(
    scope: RankingsScope.fromJson(j['scope'] as Map<String, dynamic>),
    rows: _list(j['rows'], RankingRow.fromJson),
    tabs: _list(j['tabs'], MetricTab.fromJson),
    subGames: _list(j['subGames'], SubGame.fromJson),
    subGamesAllLabel: j['subGamesAllLabel'] as String?,
    page: PageInfo.fromJson(j['page'] as Map<String, dynamic>),
    games: _list(j['games'], GameChip.fromJson),
    regions: (j['regions'] as List<dynamic>).cast<String>(),
    stats: RankingsStats.fromJson(j['stats'] as Map<String, dynamic>),
    highlights: Highlights.fromJson(j['highlights'] as Map<String, dynamic>),
  );
  final RankingsScope scope;
  final List<RankingRow> rows;
  final List<MetricTab> tabs;
  final List<SubGame> subGames;
  final String? subGamesAllLabel;
  final PageInfo page;
  final List<GameChip> games;
  final List<String> regions;
  final RankingsStats stats;
  final Highlights highlights;
}

class RankingsMe {
  const RankingsMe({required this.row});
  factory RankingsMe.fromJson(Map<String, dynamic> j) =>
      RankingsMe(row: _opt(j['row'], RankingRow.fromJson));
  final RankingRow? row;
}

class SeasonSummary {
  const SeasonSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.startDate,
    required this.endDate,
  });
  factory SeasonSummary.fromJson(Map<String, dynamic> j) => SeasonSummary(
    id: j['id'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
    startDate: j['startDate'] as String,
    endDate: j['endDate'] as String,
  );
  final String id;
  final String slug;
  final String name;
  final String startDate;
  final String endDate;
}

class SeasonTournament {
  const SeasonTournament({
    required this.id,
    required this.title,
    required this.slug,
    required this.tournamentType,
    required this.status,
    required this.tournamentStart,
    required this.invitationOnly,
  });
  factory SeasonTournament.fromJson(Map<String, dynamic> j) => SeasonTournament(
    id: j['id'] as String,
    title: j['title'] as String,
    slug: j['slug'] as String,
    tournamentType: j['tournamentType'] as String,
    status: j['status'] as String,
    tournamentStart: j['tournamentStart'] as String?,
    invitationOnly: j['invitationOnly'] as bool,
  );
  final String id;
  final String title;
  final String slug;
  final String tournamentType;
  final String status;
  final String? tournamentStart;
  final bool invitationOnly;
}

class SeasonLeaderboardRow {
  const SeasonLeaderboardRow({
    required this.playerId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.sxScore,
    required this.points,
    required this.isProvisional,
  });
  factory SeasonLeaderboardRow.fromJson(Map<String, dynamic> j) =>
      SeasonLeaderboardRow(
        playerId: j['playerId'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        sxScore: _int(j['sxScore']),
        points: _int(j['points']),
        isProvisional: j['isProvisional'] as bool,
      );
  final String playerId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int sxScore;
  final int points;
  final bool isProvisional;
}

class SeasonTierLabels {
  const SeasonTierLabels({
    required this.communityClub,
    required this.masters,
    required this.qualificationNote,
    required this.showChampionsCupSpotlight,
  });
  factory SeasonTierLabels.fromJson(Map<String, dynamic> j) => SeasonTierLabels(
    communityClub: j['communityClub'] as String,
    masters: j['masters'] as String,
    qualificationNote: j['qualificationNote'] as String,
    showChampionsCupSpotlight: j['showChampionsCupSpotlight'] as bool,
  );
  final String communityClub;
  final String masters;
  final String qualificationNote;
  final bool showChampionsCupSpotlight;
}

class SeasonGame {
  const SeasonGame({
    required this.gameId,
    required this.gameName,
    required this.gameSlug,
    required this.tournaments,
    required this.leaderboard,
    required this.tierLabels,
  });
  factory SeasonGame.fromJson(Map<String, dynamic> j) => SeasonGame(
    gameId: j['gameId'] as String,
    gameName: j['gameName'] as String,
    gameSlug: j['gameSlug'] as String,
    tournaments: _list(j['tournaments'], SeasonTournament.fromJson),
    leaderboard: _list(j['leaderboard'], SeasonLeaderboardRow.fromJson),
    tierLabels: SeasonTierLabels.fromJson(
      j['tierLabels'] as Map<String, dynamic>,
    ),
  );
  final String gameId;
  final String gameName;
  final String gameSlug;
  final List<SeasonTournament> tournaments;
  final List<SeasonLeaderboardRow> leaderboard;
  final SeasonTierLabels tierLabels;
}

class SeasonDetail {
  const SeasonDetail({required this.season, required this.games});
  factory SeasonDetail.fromJson(Map<String, dynamic> j) => SeasonDetail(
    season: SeasonSummary.fromJson(j['season'] as Map<String, dynamic>),
    games: _list(j['games'], SeasonGame.fromJson),
  );
  final SeasonSummary season;
  final List<SeasonGame> games;
}

class Placing {
  const Placing({required this.id, required this.name});
  factory Placing.fromJson(Map<String, dynamic> j) =>
      Placing(id: j['id'] as String, name: j['name'] as String);
  final String id;
  final String name;
}

class HofChampion {
  const HofChampion({
    required this.tournamentId,
    required this.slug,
    required this.title,
    required this.tournamentType,
    required this.gameId,
    required this.gameName,
    required this.date,
    required this.prizePool,
    required this.champion,
    required this.runnerUp,
    required this.championAvatarUrl,
    required this.seasonName,
  });
  factory HofChampion.fromJson(Map<String, dynamic> j) => HofChampion(
    tournamentId: j['tournamentId'] as String,
    slug: j['slug'] as String,
    title: j['title'] as String,
    tournamentType: j['tournamentType'] as String,
    gameId: j['gameId'] as String,
    gameName: j['gameName'] as String,
    date: j['date'] as String?,
    prizePool: j['prizePool'] as num?,
    champion: Placing.fromJson(j['champion'] as Map<String, dynamic>),
    runnerUp: _opt(j['runnerUp'], Placing.fromJson),
    championAvatarUrl: j['championAvatarUrl'] as String?,
    seasonName: j['seasonName'] as String?,
  );
  final String tournamentId;
  final String slug;
  final String title;
  final String tournamentType;
  final String gameId;
  final String gameName;
  final String? date;
  final num? prizePool;
  final Placing champion;
  final Placing? runnerUp;
  final String? championAvatarUrl;
  final String? seasonName;
}

class AwardOption {
  const AwardOption({
    required this.gameId,
    required this.gameLabel,
    required this.winner,
    required this.metricValue,
  });
  factory AwardOption.fromJson(Map<String, dynamic> j) => AwardOption(
    gameId: j['gameId'] as String?,
    gameLabel: j['gameLabel'] as String,
    winner: _opt(j['winner'], PlayerCard.fromJson),
    metricValue: j['metricValue'] as num,
  );
  final String? gameId;
  final String gameLabel;
  final PlayerCard? winner;
  final num metricValue;
}

class CategoryAward {
  const CategoryAward({
    required this.category,
    required this.label,
    required this.metricLabel,
    required this.options,
  });
  factory CategoryAward.fromJson(Map<String, dynamic> j) => CategoryAward(
    category: j['category'] as String,
    label: j['label'] as String,
    metricLabel: j['metricLabel'] as String,
    options: _list(j['options'], AwardOption.fromJson),
  );
  final String category;
  final String label;
  final String metricLabel;
  final List<AwardOption> options;
}

class HofAwards {
  const HofAwards({
    required this.mvp,
    required this.goldenBoot,
    required this.categories,
  });
  factory HofAwards.fromJson(Map<String, dynamic> j) => HofAwards(
    mvp: _opt(j['mvp'], PlayerCard.fromJson),
    goldenBoot: _list(j['goldenBoot'], AwardOption.fromJson),
    categories: _list(j['categories'], CategoryAward.fromJson),
  );
  final PlayerCard? mvp;
  final List<AwardOption> goldenBoot;
  final List<CategoryAward> categories;
}

class HofChampions {
  const HofChampions({
    required this.championsCup,
    required this.masters,
    required this.communityClub,
    required this.open,
  });
  factory HofChampions.fromJson(Map<String, dynamic> j) => HofChampions(
    championsCup: _list(j['championsCup'], HofChampion.fromJson),
    masters: _list(j['masters'], HofChampion.fromJson),
    communityClub: _list(j['communityClub'], HofChampion.fromJson),
    open: _list(j['open'], HofChampion.fromJson),
  );
  final List<HofChampion> championsCup;
  final List<HofChampion> masters;
  final List<HofChampion> communityClub;
  final List<HofChampion> open;
}

class BronzeFinish {
  const BronzeFinish({
    required this.tournamentId,
    required this.slug,
    required this.title,
    required this.gameName,
    required this.date,
    required this.player,
  });
  factory BronzeFinish.fromJson(Map<String, dynamic> j) => BronzeFinish(
    tournamentId: j['tournamentId'] as String,
    slug: j['slug'] as String,
    title: j['title'] as String,
    gameName: j['gameName'] as String?,
    date: j['date'] as String?,
    player: Placing.fromJson(j['player'] as Map<String, dynamic>),
  );
  final String tournamentId;
  final String slug;
  final String title;
  final String? gameName;
  final String? date;
  final Placing player;
}

class HallOfFame {
  const HallOfFame({
    required this.games,
    required this.selectedGame,
    required this.awards,
    required this.champions,
    required this.bronze,
  });
  factory HallOfFame.fromJson(Map<String, dynamic> j) => HallOfFame(
    games: _list(j['games'], GameChip.fromJson),
    selectedGame: j['selectedGame'] as String?,
    awards: HofAwards.fromJson(j['awards'] as Map<String, dynamic>),
    champions: HofChampions.fromJson(j['champions'] as Map<String, dynamic>),
    bronze: _list(j['bronze'], BronzeFinish.fromJson),
  );
  final List<GameChip> games;
  final String? selectedGame;
  final HofAwards awards;
  final HofChampions champions;
  final List<BronzeFinish> bronze;
}
