// Phase 2b wire models (bracket, standings, results, match centre, squads, dashboard summary).
// Parsed strictly from the shapes in the web repo's lib/mobile-api/endpoints/*.ts; `fromJson` only.

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v! as List<dynamic>).map((e) => f(e as Map<String, dynamic>)).toList();

Map<String, dynamic>? _obj(Object? v) => v == null ? null : v as Map<String, dynamic>;

int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => (v as num?)?.toInt();

class NameRef {
  const NameRef({required this.id, required this.name});
  factory NameRef.fromJson(Map<String, dynamic> j) => NameRef(id: j['id'] as String, name: j['name'] as String);
  static NameRef? maybe(Object? v) => v == null ? null : NameRef.fromJson(v as Map<String, dynamic>);
  final String id;
  final String name;
}

class StandingRow {
  const StandingRow({
    required this.playerId,
    required this.name,
    required this.clubName,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.rank,
    required this.advancing,
  });
  factory StandingRow.fromJson(Map<String, dynamic> j) => StandingRow(
        playerId: j['playerId'] as String,
        name: j['name'] as String,
        clubName: j['clubName'] as String?,
        played: _int(j['played']),
        wins: _int(j['wins']),
        draws: _int(j['draws']),
        losses: _int(j['losses']),
        goalsFor: _int(j['goalsFor']),
        goalsAgainst: _int(j['goalsAgainst']),
        goalDiff: _int(j['goalDiff']),
        points: _int(j['points']),
        rank: _int(j['rank']),
        advancing: j['advancing'] as bool,
      );
  final String playerId;
  final String name;
  final String? clubName;
  final int played, wins, draws, losses, goalsFor, goalsAgainst, goalDiff, points, rank;
  final bool advancing;
}

class GroupStandings {
  const GroupStandings({required this.groupId, required this.groupName, required this.rows});
  factory GroupStandings.fromJson(Map<String, dynamic> j) => GroupStandings(
        groupId: j['groupId'] as String,
        groupName: j['groupName'] as String,
        rows: _list(j['rows'], StandingRow.fromJson),
      );
  final String groupId;
  final String groupName;
  final List<StandingRow> rows;
}

class BracketFixture {
  const BracketFixture({
    required this.id,
    required this.round,
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.scheduledAt,
    required this.isFullDay,
    required this.playerA,
    required this.playerB,
  });
  // snake_case: group_id, score_a, score_b, scheduled_at, is_full_day; camelCase: groupName, playerA, playerB.
  factory BracketFixture.fromJson(Map<String, dynamic> j) => BracketFixture(
        id: j['id'] as String,
        round: j['round'] as String,
        groupId: j['group_id'] as String?,
        groupName: j['groupName'] as String?,
        status: j['status'] as String,
        scoreA: _intOrNull(j['score_a']),
        scoreB: _intOrNull(j['score_b']),
        scheduledAt: j['scheduled_at'] as String?,
        isFullDay: j['is_full_day'] as bool,
        playerA: NameRef.fromJson(j['playerA'] as Map<String, dynamic>),
        playerB: NameRef.fromJson(j['playerB'] as Map<String, dynamic>),
      );
  final String id;
  final String round;
  final String? groupId;
  final String? groupName;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final String? scheduledAt;
  final bool isFullDay;
  final NameRef playerA;
  final NameRef playerB;
}

class FixtureSplit {
  const FixtureSplit({required this.live, required this.upcoming, required this.completed, required this.disputedOrCancelled});
  factory FixtureSplit.fromJson(Map<String, dynamic> j) => FixtureSplit(
        live: _list(j['live'], BracketFixture.fromJson),
        upcoming: _list(j['upcoming'], BracketFixture.fromJson),
        completed: _list(j['completed'], BracketFixture.fromJson),
        disputedOrCancelled: _list(j['disputedOrCancelled'], BracketFixture.fromJson),
      );
  final List<BracketFixture> live, upcoming, completed, disputedOrCancelled;
  bool get isEmpty => live.isEmpty && upcoming.isEmpty && completed.isEmpty && disputedOrCancelled.isEmpty;
}

class KnockoutRound {
  const KnockoutRound({required this.round, required this.label, required this.matches});
  factory KnockoutRound.fromJson(Map<String, dynamic> j) => KnockoutRound(
        round: j['round'] as String,
        label: j['label'] as String,
        matches: _list(j['matches'], BracketFixture.fromJson),
      );
  final String round;
  final String label;
  final List<BracketFixture> matches;
}

class ProjectedRound {
  const ProjectedRound({required this.round, required this.label, required this.matchCount});
  factory ProjectedRound.fromJson(Map<String, dynamic> j) =>
      ProjectedRound(round: j['round'] as String, label: j['label'] as String, matchCount: _int(j['matchCount']));
  final String round;
  final String label;
  final int matchCount;
}

class BracketView {
  const BracketView({
    required this.standings,
    required this.fixtures,
    required this.rounds,
    required this.projected,
    required this.champion,
    required this.thirdPlace,
    required this.thirdPlaceMatch,
    required this.hasGroups,
    required this.hasKnockout,
  });
  factory BracketView.fromJson(Map<String, dynamic> j) {
    final tp = _obj(j['thirdPlaceMatch']);
    return BracketView(
      standings: _list(j['standings'], GroupStandings.fromJson),
      fixtures: FixtureSplit.fromJson(j['fixtures'] as Map<String, dynamic>),
      rounds: _list(j['rounds'], KnockoutRound.fromJson),
      projected: _list(j['projected'], ProjectedRound.fromJson),
      champion: NameRef.maybe(j['champion']),
      thirdPlace: NameRef.maybe(j['thirdPlace']),
      thirdPlaceMatch: tp == null ? null : BracketFixture.fromJson(tp),
      hasGroups: j['hasGroups'] as bool,
      hasKnockout: j['hasKnockout'] as bool,
    );
  }
  final List<GroupStandings> standings;
  final FixtureSplit fixtures;
  final List<KnockoutRound> rounds;
  final List<ProjectedRound> projected;
  final NameRef? champion;
  final NameRef? thirdPlace;
  final BracketFixture? thirdPlaceMatch;
  final bool hasGroups;
  final bool hasKnockout;
}

class PointsStandingRow {
  const PointsStandingRow({
    required this.entrantId,
    required this.displayName,
    required this.played,
    required this.totalPoints,
    required this.totalKills,
    required this.bestPlacement,
    required this.lastRoundPlacement,
    required this.rank,
    required this.advancing,
    required this.unresolvedTieWith,
  });
  factory PointsStandingRow.fromJson(Map<String, dynamic> j) => PointsStandingRow(
        entrantId: j['entrantId'] as String,
        displayName: j['displayName'] as String,
        played: _int(j['played']),
        totalPoints: _int(j['totalPoints']),
        totalKills: _int(j['totalKills']),
        bestPlacement: _intOrNull(j['bestPlacement']),
        lastRoundPlacement: _intOrNull(j['lastRoundPlacement']),
        rank: _int(j['rank']),
        advancing: j['advancing'] as bool,
        unresolvedTieWith: (j['unresolvedTieWith'] as List<dynamic>).cast<String>(),
      );
  final String entrantId;
  final String displayName;
  final int played, totalPoints, totalKills;
  final int? bestPlacement, lastRoundPlacement;
  final int rank;
  final bool advancing;
  final List<String> unresolvedTieWith;
}

class ChampionEntry {
  const ChampionEntry({
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
  factory ChampionEntry.fromJson(Map<String, dynamic> j) => ChampionEntry(
        tournamentId: j['tournamentId'] as String,
        slug: j['slug'] as String,
        title: j['title'] as String,
        tournamentType: j['tournamentType'] as String,
        gameId: j['gameId'] as String,
        gameName: j['gameName'] as String,
        date: j['date'] as String?,
        prizePool: _intOrNull(j['prizePool']),
        champion: NameRef.fromJson(j['champion'] as Map<String, dynamic>),
        runnerUp: NameRef.maybe(j['runnerUp']),
        championAvatarUrl: j['championAvatarUrl'] as String?,
        seasonName: j['seasonName'] as String?,
      );
  final String tournamentId, slug, title, tournamentType, gameId, gameName;
  final String? date;
  final int? prizePool;
  final NameRef champion;
  final NameRef? runnerUp;
  final String? championAvatarUrl;
  final String? seasonName;
}

class TournamentResults {
  const TournamentResults({required this.champion, required this.noWinner});
  factory TournamentResults.fromJson(Map<String, dynamic> j) {
    final c = _obj(j['champion']);
    return TournamentResults(champion: c == null ? null : ChampionEntry.fromJson(c), noWinner: j['noWinner'] as bool);
  }
  final ChampionEntry? champion;
  final bool noWinner;
}

enum CheckInVerdict { both, one, none }

CheckInVerdict _verdict(String s) => switch (s) {
      'both' => CheckInVerdict.both,
      'one' => CheckInVerdict.one,
      'none' => CheckInVerdict.none,
      _ => throw FormatException('Unknown check-in verdict: $s'),
    };

class WagerInfo {
  const WagerInfo({
    required this.windowOpen,
    required this.poolA,
    required this.poolB,
    required this.feeRate,
    required this.minStake,
    required this.maxStake,
    required this.myPickPlayerId,
    required this.myStakeCoins,
    required this.estimatedPayoutIfIStakeA100,
  });
  factory WagerInfo.fromJson(Map<String, dynamic> j) {
    final pools = j['pools'] as Map<String, dynamic>;
    return WagerInfo(
      windowOpen: j['windowOpen'] as bool,
      poolA: _int(pools['playerA']),
      poolB: _int(pools['playerB']),
      feeRate: (j['feeRate'] as num).toDouble(),
      minStake: _int(j['minStake']),
      maxStake: _int(j['maxStake']),
      myPickPlayerId: j['myPickPlayerId'] as String?,
      myStakeCoins: _intOrNull(j['myStakeCoins']),
      estimatedPayoutIfIStakeA100: j['estimatedPayoutIfIStakeA100'] as num,
    );
  }
  final bool windowOpen;
  final int poolA, poolB;
  final double feeRate;
  final int minStake, maxStake;
  final String? myPickPlayerId;
  final int? myStakeCoins;
  final num estimatedPayoutIfIStakeA100;
}

class MatchCentre {
  const MatchCentre({
    required this.matchId,
    required this.status,
    required this.scheduledAt,
    required this.isFullDay,
    required this.isParticipant,
    required this.canCheckIn,
    required this.checkedInPlayerIds,
    required this.checkInVerdict,
    required this.soleAttendeeId,
    required this.wager,
    required this.noShowEligible,
  });
  factory MatchCentre.fromJson(Map<String, dynamic> j) => MatchCentre(
        matchId: j['matchId'] as String,
        status: j['status'] as String,
        scheduledAt: j['scheduledAt'] as String?,
        isFullDay: j['isFullDay'] as bool,
        isParticipant: j['isParticipant'] as bool,
        canCheckIn: j['canCheckIn'] as bool,
        checkedInPlayerIds: (j['checkedInPlayerIds'] as List<dynamic>).cast<String>(),
        checkInVerdict: _verdict(j['checkInVerdict'] as String),
        soleAttendeeId: j['soleAttendeeId'] as String?,
        wager: WagerInfo.fromJson(j['wager'] as Map<String, dynamic>),
        noShowEligible: j['noShowEligible'] as bool,
      );
  final String matchId;
  final String status;
  final String? scheduledAt;
  final bool isFullDay, isParticipant, canCheckIn;
  final List<String> checkedInPlayerIds;
  final CheckInVerdict checkInVerdict;
  final String? soleAttendeeId;
  final WagerInfo wager;
  final bool noShowEligible;
}

class SquadPreview {
  const SquadPreview({required this.id, required this.name, required this.memberCount, required this.teamSize});
  factory SquadPreview.fromJson(Map<String, dynamic> j) =>
      SquadPreview(id: j['id'] as String, name: j['name'] as String, memberCount: _int(j['memberCount']), teamSize: _int(j['teamSize']));
  final String id, name;
  final int memberCount, teamSize;
}

class CreatedSquad {
  const CreatedSquad({required this.squadId, required this.inviteCode});
  factory CreatedSquad.fromJson(Map<String, dynamic> j) =>
      CreatedSquad(squadId: j['squadId'] as String, inviteCode: j['inviteCode'] as String);
  final String squadId, inviteCode;
}

class NextMatch {
  const NextMatch({
    required this.id,
    required this.status,
    required this.round,
    required this.scheduledAt,
    required this.isFullDay,
    required this.tournamentTitle,
  });
  factory NextMatch.fromJson(Map<String, dynamic> j) => NextMatch(
        id: j['id'] as String,
        status: j['status'] as String,
        round: j['round'] as String,
        scheduledAt: j['scheduledAt'] as String?,
        isFullDay: j['isFullDay'] as bool,
        tournamentTitle: j['tournamentTitle'] as String,
      );
  final String id, status, round;
  final String? scheduledAt;
  final bool isFullDay;
  final String tournamentTitle;
}

class NextLobby {
  const NextLobby({
    required this.lobbyId,
    required this.tournamentTitle,
    required this.stageName,
    required this.roundNo,
    required this.label,
    required this.scheduledAt,
    required this.hasRoomCode,
    required this.submitted,
  });
  factory NextLobby.fromJson(Map<String, dynamic> j) => NextLobby(
        lobbyId: j['lobbyId'] as String,
        tournamentTitle: j['tournamentTitle'] as String,
        stageName: j['stageName'] as String,
        roundNo: _int(j['roundNo']),
        label: j['label'] as String,
        scheduledAt: j['scheduledAt'] as String?,
        hasRoomCode: j['hasRoomCode'] as bool,
        submitted: j['submitted'] as bool,
      );
  final String lobbyId, tournamentTitle, stageName, label;
  final int roundNo;
  final String? scheduledAt;
  final bool hasRoomCode, submitted;
}

class SummaryRegistration {
  const SummaryRegistration({required this.id, required this.paymentStatus, required this.tournamentTitle, required this.tournamentSlug});
  factory SummaryRegistration.fromJson(Map<String, dynamic> j) => SummaryRegistration(
        id: j['id'] as String,
        paymentStatus: j['paymentStatus'] as String,
        tournamentTitle: j['tournamentTitle'] as String,
        tournamentSlug: j['tournamentSlug'] as String,
      );
  final String id, paymentStatus, tournamentTitle, tournamentSlug;
}

enum BannerKind { qualified, eliminated }

class SummaryBanner {
  const SummaryBanner({
    required this.kind,
    required this.tournamentTitle,
    required this.tournamentSlug,
    required this.round,
    required this.awaitingOpponent,
  });
  factory SummaryBanner.fromJson(Map<String, dynamic> j) {
    final kind = switch (j['kind'] as String) {
      'qualified' => BannerKind.qualified,
      'eliminated' => BannerKind.eliminated,
      final k => throw FormatException('Unknown banner kind: $k'),
    };
    return SummaryBanner(
      kind: kind,
      tournamentTitle: j['tournamentTitle'] as String,
      tournamentSlug: j['tournamentSlug'] as String,
      round: j['round'] as String,
      awaitingOpponent: kind == BannerKind.qualified ? j['awaitingOpponent'] as bool : false,
    );
  }
  final BannerKind kind;
  final String tournamentTitle, tournamentSlug, round;
  final bool awaitingOpponent;
}

class MeSummary {
  const MeSummary({
    required this.nextMatch,
    required this.nextLobby,
    required this.hasSubmittableMatch,
    required this.registrations,
    required this.banners,
  });
  factory MeSummary.fromJson(Map<String, dynamic> j) {
    final m = _obj(j['nextMatch']);
    final l = _obj(j['nextLobby']);
    return MeSummary(
      nextMatch: m == null ? null : NextMatch.fromJson(m),
      nextLobby: l == null ? null : NextLobby.fromJson(l),
      hasSubmittableMatch: j['hasSubmittableMatch'] as bool,
      registrations: _list(j['registrations'], SummaryRegistration.fromJson),
      banners: _list(j['banners'], SummaryBanner.fromJson),
    );
  }
  final NextMatch? nextMatch;
  final NextLobby? nextLobby;
  final bool hasSubmittableMatch;
  final List<SummaryRegistration> registrations;
  final List<SummaryBanner> banners;
  bool get isEmpty =>
      nextMatch == null &&
      nextLobby == null &&
      banners.isEmpty &&
      registrations.every((r) => r.paymentStatus != 'pending');
}
