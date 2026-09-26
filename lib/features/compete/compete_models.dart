enum TournamentTab { all, live, upcoming, completed }

Map<String, dynamic>? _one(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is List && v.isNotEmpty && v.first is Map<String, dynamic>) return v.first as Map<String, dynamic>;
  return null;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

class CompeteTournament {
  const CompeteTournament({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.bannerUrl,
    required this.cardImageUrl,
    required this.status,
    required this.format,
    required this.competitionFormat,
    required this.prizePool,
    required this.prizeSecond,
    required this.prizeThird,
    required this.registrationFee,
    required this.maxPlayers,
    required this.registrationStart,
    required this.registrationEnd,
    required this.tournamentStart,
    required this.tournamentEnd,
    required this.rules,
    required this.invitationOnly,
    required this.gameName,
    required this.gameSlug,
  });

  factory CompeteTournament.fromJson(Map<String, dynamic> j) {
    final game = _one(j['games']);
    return CompeteTournament(
      id: j['id'] as String,
      title: j['title'] as String,
      slug: j['slug'] as String,
      description: j['description'] as String?,
      bannerUrl: j['banner_url'] as String?,
      cardImageUrl: j['card_image_url'] as String?,
      status: j['status'] as String,
      format: j['format'] as String,
      competitionFormat: j['competition_format'] as String,
      prizePool: (j['prize_pool'] as num).toInt(),
      prizeSecond: (j['prize_second'] as num?)?.toInt(),
      prizeThird: (j['prize_third'] as num?)?.toInt(),
      registrationFee: (j['registration_fee'] as num).toInt(),
      maxPlayers: (j['max_players'] as num?)?.toInt(),
      registrationStart: _date(j['registration_start']),
      registrationEnd: _date(j['registration_end']),
      tournamentStart: _date(j['tournament_start']),
      tournamentEnd: _date(j['tournament_end']),
      rules: j['rules'] as String?,
      invitationOnly: j['invitation_only'] as bool? ?? false,
      gameName: game?['name'] as String?,
      gameSlug: game?['slug'] as String?,
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? bannerUrl;
  final String? cardImageUrl;
  final String status;
  final String format;
  final String competitionFormat;
  final int prizePool;
  final int? prizeSecond;
  final int? prizeThird;
  final int registrationFee;
  final int? maxPlayers;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? tournamentStart;
  final DateTime? tournamentEnd;
  final String? rules;
  final bool invitationOnly;
  final String? gameName;
  final String? gameSlug;
}

class GameSummary {
  const GameSummary({required this.id, required this.name, required this.slug, required this.iconUrl});

  factory GameSummary.fromJson(Map<String, dynamic> j) => GameSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        iconUrl: j['icon_url'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
}

class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.tournamentId,
    required this.tournamentTitle,
    required this.registrationFee,
    required this.expiresAt,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> j) {
    final t = _one(j['tournament']);
    return PendingInvitation(
      id: j['id'] as String,
      tournamentId: j['tournament_id'] as String,
      tournamentTitle: t?['title'] as String? ?? '',
      registrationFee: (t?['registration_fee'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(j['expires_at'] as String),
    );
  }

  final String id;
  final String tournamentId;
  final String tournamentTitle;
  final int registrationFee;
  final DateTime expiresAt;
}
